# PATCH-ID: NETZIP-NOREGRESSION-20260902-v1.1.7
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [int]$LookbackDays = -1,
    [int]$MaxExecutions = -1,
    [string]$StartTime = "",
    [string]$EndTime = "",
    [switch]$AdditionalEvidence,
    [switch]$StaticOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. $ConfigPath

if ($LookbackDays -eq 0 -or $LookbackDays -lt -1 -or $MaxExecutions -lt -1) {
    throw "LookbackDays must be -1 or positive; MaxExecutions must be -1, 0, or positive."
}
if ($LookbackDays -gt 0) { $Config.LookbackDays = $LookbackDays }
if ($MaxExecutions -ge 0) { $Config.MaxExecutions = $MaxExecutions }
if ($StaticOnly) {
    $Config.CollectStatic = $true
    $Config.CollectRuntime = $false
    $Config.CollectMessages = $false
    $Config.CollectQueryStore = $false
}
if (!$Config.ContainsKey("CollectAdditionalEvidence")) { $Config.CollectAdditionalEvidence = $false }
if (!$Config.ContainsKey("AdditionalEvidenceDatabases")) { $Config.AdditionalEvidenceDatabases = @() }
if ($AdditionalEvidence) { $Config.CollectAdditionalEvidence = $true }

function Convert-WindowTime {
    param([string]$Value, [string]$Name)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [datetime]::MinValue
    if (![datetime]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeLocal, [ref]$parsed)) {
        throw "$Name is not a valid datetime: $Value"
    }
    return $parsed
}

$windowStart = Convert-WindowTime $StartTime "StartTime"
$windowEnd = Convert-WindowTime $EndTime "EndTime"
if ($windowStart -and $windowEnd -and $windowStart -ge $windowEnd) { throw "StartTime must be earlier than EndTime." }

$logPath = Join-Path $OutputPath "collector.log"

function Write-Log {
    param([string]$Level, [string]$Message)
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

function Convert-ToCsvSafe {
    param($Rows, [string]$Path)
    if ($null -eq $Rows) {
        "" | Set-Content -Path $Path
        return
    }
    @($Rows) | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function New-ConnectionString {
    param([string]$Database)
    if ($Config.UseWindowsAuthentication) {
        return "Server=$($Config.ServerInstance);Database=$Database;Integrated Security=SSPI;Application Name=SSIS Evidence Collector;"
    }
    return "Server=$($Config.ServerInstance);Database=$Database;User ID=$($Config.SqlUsername);Password=$($Config.SqlPassword);Application Name=SSIS Evidence Collector;"
}

function Invoke-SqlQuery {
    param(
        [string]$Database,
        [string]$Query,
        [int]$Timeout = 120
    )

    $cn = New-Object System.Data.SqlClient.SqlConnection
    $cn.ConnectionString = New-ConnectionString -Database $Database
    $cmd = $cn.CreateCommand()
    $cmd.CommandText = $Query
    $cmd.CommandTimeout = $Timeout
    $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $dt = New-Object System.Data.DataTable

    try {
        $cn.Open()
        [void]$da.Fill($dt)
        return $dt
    }
    finally {
        if ($cn.State -ne [System.Data.ConnectionState]::Closed) { $cn.Close() }
        $cn.Dispose()
        $cmd.Dispose()
        $da.Dispose()
    }
}

function Escape-SqlLiteral {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    return $Value.Replace("'", "''")
}

function Build-InFilter {
    param([string]$Column, [object[]]$Values)
    if ($null -eq $Values -or @($Values).Count -eq 0) { return "" }
    $quoted = @()
    foreach ($v in @($Values)) {
        if (![string]::IsNullOrWhiteSpace([string]$v)) {
            $quoted += "'$(Escape-SqlLiteral ([string]$v))'"
        }
    }
    if ($quoted.Count -eq 0) { return "" }
    return " AND $Column IN (" + ($quoted -join ",") + ")"
}

function Collect-Query {
    param(
        [string]$Name,
        [string]$Folder,
        [string]$Database,
        [string]$Query
    )

    $target = Join-Path (Join-Path $OutputPath $Folder) ($Name + ".csv")
    Write-Log "INFO" "START :: $Name"
    try {
        $rows = Invoke-SqlQuery -Database $Database -Query $Query -Timeout $Config.SqlCommandTimeoutSeconds
        Convert-ToCsvSafe -Rows $rows -Path $target
        $rowCount = 0
        if ($null -eq $rows) {
            $rowCount = 0
        }
        elseif ($rows -is [System.Data.DataTable]) {
            $rowCount = $rows.Rows.Count
        }
        elseif ($rows -is [System.Array]) {
            $rowCount = $rows.Count
        }
        else {
            $rowCount = @($rows).Count
        }
        Write-Log "INFO" "SUCCESS :: $Name :: Rows=$rowCount"
    }
    catch {
        Write-Log "WARN" "FAILED :: $Name :: $($_.Exception.Message)"
        "ERROR: $($_.Exception.Message)" | Set-Content -Path ($target + ".error.txt")
    }
}

# ------------------------------------------------------------
# Manifest / environment
# ------------------------------------------------------------
$manifestDir = Join-Path $OutputPath "00_manifest"
$env = New-Object PSObject -Property @{
    CollectedAt = (Get-Date).ToString("s")
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    ServerInstance = $Config.ServerInstance
    LookbackDays = $Config.LookbackDays
    MaxExecutions = $Config.MaxExecutions
    ExplicitStartTime = $StartTime
    ExplicitEndTime = $EndTime
    CollectStatic = $Config.CollectStatic
    CollectRuntime = $Config.CollectRuntime
    IspacRoot = $Config.IspacRoot
    CollectMessages = $Config.CollectMessages
    CollectQueryStore = $Config.CollectQueryStore
    CollectAdditionalEvidence = $Config.CollectAdditionalEvidence
    AdditionalEvidenceDatabases = (@($Config.AdditionalEvidenceDatabases) -join ";")
}
$env | Export-Csv (Join-Path $manifestDir "collector_environment.csv") -NoTypeInformation -Encoding UTF8

# ------------------------------------------------------------
# Static evidence from exported ISPAC files
# ------------------------------------------------------------
$staticDir = Join-Path $OutputPath "01_static_packages"
$ispacOriginalDir = Join-Path $staticDir "ispac_original"
$extractDir = Join-Path $staticDir "extracted"
$ispacInventory = @()
$staticInventory = @()
$packageInventory = @()

function Get-Sha256 {
    param([string]$Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $bytes = $sha.ComputeHash($stream)
            return ([System.BitConverter]::ToString($bytes)).Replace("-", "")
        }
        finally { $stream.Dispose(); $sha.Dispose() }
    }
    catch { return "HASH_FAILED" }
}

function Get-RelativePathLegacy {
    param([string]$Root, [string]$FullName)
    $rootNormalized = [System.IO.Path]::GetFullPath($Root).TrimEnd([char[]]@(92,47))
    $fullNormalized = [System.IO.Path]::GetFullPath($FullName)
    if ($fullNormalized.StartsWith($rootNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullNormalized.Substring($rootNormalized.Length).TrimStart([char[]]@(92,47))
    }
    return [System.IO.Path]::GetFileName($FullName)
}

function Expand-IspacLegacy {
    param([string]$IspacPath, [string]$Destination)

    if (!(Test-Path -LiteralPath $IspacPath)) {
        throw "ISPAC file not found: $IspacPath"
    }

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    try {
        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
    }
    catch {
        throw "Could not load .NET ZIP support (System.IO.Compression.FileSystem): $($_.Exception.Message)"
    }

    $archive = $null
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($IspacPath)
        if ($archive.Entries.Count -eq 0) {
            throw "ISPAC archive contains no entries."
        }
    }
    catch {
        throw "ISPAC is not a readable ZIP archive: $IspacPath :: $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $archive) { $archive.Dispose() }
    }

    try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($IspacPath, $Destination)
    }
    catch {
        throw "Failed to extract ISPAC: $IspacPath :: $($_.Exception.Message)"
    }

    $fileCount = @(Get-ChildItem -LiteralPath $Destination -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }).Count
    if ($fileCount -eq 0) {
        throw "ISPAC extraction produced no files: $IspacPath"
    }
}

function Get-DtsxSummary {
    param([string]$Path, [string]$CatalogName, [string]$FolderName, [string]$ProjectName, [string]$IspacRelativePath)
    try {
        [xml]$xml = Get-Content -LiteralPath $Path -Raw
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace("DTS", "www.microsoft.com/SqlServer/Dts")

        $executables = @($xml.SelectNodes("//*[local-name()='Executable']"))
        $components = @($xml.SelectNodes("//*[local-name()='component']"))
        $paths = @($xml.SelectNodes("//*[local-name()='path']"))
        $connections = @($xml.SelectNodes("//*[local-name()='ConnectionManager']"))

        $componentNames = @()
        $componentClasses = @()
        foreach ($c in $components) {
            if ($c.name) { $componentNames += [string]$c.name }
            if ($c.componentClassID) { $componentClasses += [string]$c.componentClassID }
        }
        $joined = (($componentNames + $componentClasses) -join " | ")

        return New-Object PSObject -Property @{
            CatalogName = $CatalogName
            FolderName = $FolderName
            ProjectName = $ProjectName
            PackageName = [System.IO.Path]::GetFileName($Path)
            IspacRelativePath = $IspacRelativePath
            ExecutableNodeCount = $executables.Count
            DataFlowComponentCount = $components.Count
            DataFlowPathCount = $paths.Count
            ConnectionManagerNodeCount = $connections.Count
            HasSortIndicator = [bool]($joined -match '(?i)sort')
            HasAggregateIndicator = [bool]($joined -match '(?i)aggregate')
            HasLookupIndicator = [bool]($joined -match '(?i)lookup')
            HasMergeIndicator = [bool]($joined -match '(?i)merge')
            HasScriptIndicator = [bool]($joined -match '(?i)script')
            ParseStatus = "OK"
            ParseError = ""
        }
    }
    catch {
        return New-Object PSObject -Property @{
            CatalogName = $CatalogName
            FolderName = $FolderName
            ProjectName = $ProjectName
            PackageName = [System.IO.Path]::GetFileName($Path)
            IspacRelativePath = $IspacRelativePath
            ExecutableNodeCount = $null
            DataFlowComponentCount = $null
            DataFlowPathCount = $null
            ConnectionManagerNodeCount = $null
            HasSortIndicator = $null
            HasAggregateIndicator = $null
            HasLookupIndicator = $null
            HasMergeIndicator = $null
            HasScriptIndicator = $null
            ParseStatus = "FAILED"
            ParseError = $_.Exception.Message
        }
    }
}

if ($Config.CollectStatic) {
    if (-not $Config.ContainsKey("IspacRoot") -or [string]::IsNullOrWhiteSpace([string]$Config.IspacRoot)) {
        Write-Log "WARN" "CollectStatic=true but IspacRoot is empty. Static evidence skipped."
    }
    elseif (!(Test-Path -LiteralPath $Config.IspacRoot)) {
        Write-Log "WARN" "IspacRoot not found: $($Config.IspacRoot). Static evidence skipped."
    }
    else {
        $ispacs = @(Get-ChildItem -LiteralPath $Config.IspacRoot -Filter "*.ispac" -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })
        Write-Log "INFO" "ISPAC discovery :: Root=$($Config.IspacRoot) :: Count=$($ispacs.Count)"

        foreach ($ispac in $ispacs) {
            $relative = Get-RelativePathLegacy -Root $Config.IspacRoot -FullName $ispac.FullName
            $relativeDir = Split-Path $relative -Parent
            $segments = @($relative -split '[\\/]')
            $catalogName = if ($segments.Count -ge 3) { $segments[0] } else { "" }
            $folderName = if ($segments.Count -ge 3) { $segments[$segments.Count - 2] } elseif ($segments.Count -ge 2) { $segments[0] } else { "" }
            $projectName = $ispac.BaseName

            $originalDest = Join-Path $ispacOriginalDir $relative
            $originalParent = Split-Path $originalDest -Parent
            if (!(Test-Path $originalParent)) { New-Item -ItemType Directory -Path $originalParent -Force | Out-Null }
            Copy-Item -LiteralPath $ispac.FullName -Destination $originalDest -Force

            $projectExtract = Join-Path $extractDir (Join-Path $relativeDir $projectName)
            Write-Log "INFO" "START :: ISPAC :: $relative"
            $extractStatus = "OK"
            $extractError = ""
            try {
                Expand-IspacLegacy -IspacPath $ispac.FullName -Destination $projectExtract
                Write-Log "INFO" "SUCCESS :: ISPAC :: $relative"
            }
            catch {
                $extractStatus = "FAILED"
                $extractError = $_.Exception.Message
                Write-Log "WARN" "FAILED :: ISPAC :: $relative :: $extractError"
            }

            $ispacInventory += New-Object PSObject -Property @{
                CatalogName = $catalogName
                FolderName = $folderName
                ProjectName = $projectName
                IspacName = $ispac.Name
                RelativePath = $relative
                SourceFullName = $ispac.FullName
                LengthBytes = $ispac.Length
                LastWriteTime = $ispac.LastWriteTime
                SHA256 = Get-Sha256 $ispac.FullName
                ExtractStatus = $extractStatus
                ExtractError = $extractError
            }

            if ($extractStatus -eq "OK") {
                $files = @(Get-ChildItem -LiteralPath $projectExtract -Recurse -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer })
                foreach ($f in $files) {
                    $staticInventory += New-Object PSObject -Property @{
                        CatalogName = $catalogName
                        FolderName = $folderName
                        ProjectName = $projectName
                        IspacRelativePath = $relative
                        ExtractedRelativePath = Get-RelativePathLegacy -Root $projectExtract -FullName $f.FullName
                        Extension = $f.Extension
                        LengthBytes = $f.Length
                        SHA256 = Get-Sha256 $f.FullName
                    }
                    if ($f.Extension -ieq ".dtsx") {
                        $packageInventory += Get-DtsxSummary -Path $f.FullName -CatalogName $catalogName -FolderName $folderName -ProjectName $projectName -IspacRelativePath $relative
                    }
                }
            }
        }
    }
}
else {
    Write-Log "INFO" "Static ISPAC collection disabled."
}

Convert-ToCsvSafe -Rows $ispacInventory -Path (Join-Path $manifestDir "ispac_inventory.csv")
Convert-ToCsvSafe -Rows $staticInventory -Path (Join-Path $manifestDir "static_file_inventory.csv")
Convert-ToCsvSafe -Rows $packageInventory -Path (Join-Path $staticDir "package_static_summary.csv")

# ------------------------------------------------------------
# SSISDB runtime evidence
# ------------------------------------------------------------
if ($Config.CollectRuntime) {
    # ------------------------------------------------------------
    # SSISDB filters
    # ------------------------------------------------------------
    $folderFilter  = Build-InFilter "folder_name" $Config.FolderNames
    $projectFilter = Build-InFilter "project_name" $Config.ProjectNames
    $packageFilter = Build-InFilter "package_name" $Config.PackageNames
    $lookback = [int]$Config.LookbackDays
    $maxExec = [int]$Config.MaxExecutions
    $executionTop = if ($maxExec -gt 0) { "TOP ($maxExec)" } else { "" }

    # ------------------------------------------------------------
    # Connectivity
    # ------------------------------------------------------------
    Collect-Query "server_identity" "00_manifest" "master" @"
    SELECT @@SERVERNAME AS server_name,
           CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS product_version,
           CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)) AS product_level,
           CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS edition,
           GETDATE() AS server_time;
"@

    # ------------------------------------------------------------
    # SSISDB inventory
    # ------------------------------------------------------------
    Collect-Query "folders" "02_ssisdb_inventory" "SSISDB" @"
    SELECT folder_id, name, description, created_time
    FROM catalog.folders
    ORDER BY name;
"@

    Collect-Query "projects" "02_ssisdb_inventory" "SSISDB" @"
    SELECT f.name AS folder_name, p.project_id, p.name AS project_name,
           p.description, p.created_time, p.last_deployed_time, p.validation_status
    FROM catalog.projects p
    JOIN catalog.folders f ON p.folder_id=f.folder_id
    ORDER BY f.name,p.name;
"@

    Collect-Query "packages" "02_ssisdb_inventory" "SSISDB" @"
    SELECT f.name AS folder_name, p.name AS project_name,
           pkg.package_id, pkg.name AS package_name,
           pkg.entry_point, pkg.description, pkg.package_format_version,
           pkg.version_major, pkg.version_minor, pkg.version_build,
           pkg.version_comments
    FROM catalog.packages pkg
    JOIN catalog.projects p ON pkg.project_id=p.project_id
    JOIN catalog.folders f ON p.folder_id=f.folder_id
    ORDER BY f.name,p.name,pkg.name;
"@

    Collect-Query "environments" "02_ssisdb_inventory" "SSISDB" @"
    SELECT f.name AS folder_name, e.environment_id, e.name AS environment_name,
           e.description, e.created_time
    FROM catalog.environments e
    JOIN catalog.folders f ON e.folder_id=f.folder_id
    ORDER BY f.name,e.name;
"@

    Collect-Query "environment_variables" "02_ssisdb_inventory" "SSISDB" @"
    SELECT f.name AS folder_name, e.name AS environment_name,
           v.variable_id, v.name AS variable_name, v.type,
           v.sensitive, v.description
    FROM catalog.environment_variables v
    JOIN catalog.environments e ON v.environment_id=e.environment_id
    JOIN catalog.folders f ON e.folder_id=f.folder_id
    ORDER BY f.name,e.name,v.name;
"@

    Collect-Query "object_parameters" "02_ssisdb_inventory" "SSISDB" @"
    SELECT object_type, object_name, parameter_name, data_type,
           required, sensitive, description, value_type,
           CASE WHEN sensitive=1 THEN NULL ELSE CAST(default_value AS nvarchar(4000)) END AS default_value_non_sensitive,
           CASE WHEN sensitive=1 THEN NULL ELSE CAST(design_default_value AS nvarchar(4000)) END AS design_default_value_non_sensitive
    FROM catalog.object_parameters
    ORDER BY object_type,object_name,parameter_name;
"@

    # ------------------------------------------------------------
    # Core runtime executions
    # ------------------------------------------------------------
    if ($windowStart -or $windowEnd) {
        $windowPredicates = @()
        if ($windowStart) { $windowPredicates += "start_time >= CONVERT(datetime, '" + $windowStart.ToString("yyyy-MM-ddTHH:mm:ss") + "', 126)" }
        if ($windowEnd) { $windowPredicates += "start_time < CONVERT(datetime, '" + $windowEnd.ToString("yyyy-MM-ddTHH:mm:ss") + "', 126)" }
        $executionWhere = "WHERE " + ($windowPredicates -join " AND ") + " $folderFilter $projectFilter $packageFilter"
    }
    else {
        $executionWhere = "WHERE start_time >= DATEADD(day,-$lookback,GETDATE()) $folderFilter $projectFilter $packageFilter"
    }

    Collect-Query "executions" "03_runtime" "SSISDB" @"
    SELECT $executionTop
           execution_id, folder_name, project_name, package_name,
           environment_name, executed_as_name,
           use32bitruntime, reference_id,
           start_time, end_time,
           DATEDIFF(ms,start_time,end_time) AS duration_ms,
           status,
           CASE status
             WHEN 1 THEN 'Created' WHEN 2 THEN 'Running' WHEN 3 THEN 'Canceled'
             WHEN 4 THEN 'Failed' WHEN 5 THEN 'Pending' WHEN 6 THEN 'EndedUnexpectedly'
             WHEN 7 THEN 'Succeeded' WHEN 8 THEN 'Stopping' WHEN 9 THEN 'Completed'
             ELSE CAST(status AS varchar(20)) END AS status_desc,
           caller_name, process_id, server_name
    FROM catalog.executions
    $executionWhere
    ORDER BY execution_id DESC;
"@

    $execScope = @"
    SELECT $executionTop execution_id
    FROM catalog.executions
    $executionWhere
    ORDER BY execution_id DESC
"@

    Collect-Query "executable_statistics" "03_runtime" "SSISDB" @"
    WITH E AS ($execScope)
    SELECT s.execution_id, s.statistics_id, s.executable_id,
           s.execution_path, s.start_time, s.end_time,
           DATEDIFF(ms,s.start_time,s.end_time) AS duration_ms,
           s.execution_duration, s.execution_result
    FROM catalog.executable_statistics s
    JOIN E ON s.execution_id=E.execution_id
    ORDER BY s.execution_id DESC, s.start_time;
"@

    Collect-Query "execution_component_phases" "03_runtime" "SSISDB" @"
    WITH E AS ($execScope)
    SELECT p.execution_id, p.package_name, p.task_name, p.subcomponent_name,
           p.phase, p.start_time, p.end_time,
           DATEDIFF(ms,p.start_time,p.end_time) AS duration_ms
    FROM catalog.execution_component_phases p
    JOIN E ON p.execution_id=E.execution_id
    ORDER BY p.execution_id DESC,p.start_time;
"@

    Collect-Query "execution_data_statistics" "03_runtime" "SSISDB" @"
    WITH E AS ($execScope)
    SELECT d.execution_id, d.package_name, d.task_name,
           d.dataflow_path_id_string AS dataflow_path_id, d.dataflow_path_name,
           d.source_component_name, d.destination_component_name,
           d.rows_sent, d.created_time
    FROM catalog.execution_data_statistics d
    JOIN E ON d.execution_id=E.execution_id
    ORDER BY d.execution_id DESC,d.created_time;
"@

    # Aggregated rankings for immediate usability
    Collect-Query "package_runtime_summary" "03_runtime" "SSISDB" @"
    SELECT TOP (200)
           folder_name, project_name, package_name,
           COUNT(*) AS executions,
           SUM(CASE WHEN status=7 THEN 1 ELSE 0 END) AS succeeded,
           SUM(CASE WHEN status IN (4,6) THEN 1 ELSE 0 END) AS failed_or_unexpected,
           CAST(AVG(CAST(DATEDIFF(ms,start_time,end_time) AS bigint))/1000.0 AS decimal(18,2)) AS avg_duration_sec,
           CAST(MAX(CAST(DATEDIFF(ms,start_time,end_time) AS bigint))/1000.0 AS decimal(18,2)) AS max_duration_sec,
           MAX(start_time) AS last_start_time
    FROM catalog.executions
    $executionWhere
    AND end_time IS NOT NULL
    GROUP BY folder_name,project_name,package_name
    ORDER BY avg_duration_sec DESC;
"@

    Collect-Query "slow_executables" "03_runtime" "SSISDB" @"
    WITH E AS ($execScope)
    SELECT TOP (1000)
           s.execution_id, s.execution_path,
           s.start_time,s.end_time,
           DATEDIFF(ms,s.start_time,s.end_time) AS duration_ms,
           s.execution_result
    FROM catalog.executable_statistics s
    JOIN E ON s.execution_id=E.execution_id
    WHERE s.end_time IS NOT NULL
    ORDER BY duration_ms DESC;
"@

    # ------------------------------------------------------------
    # Messages - filtered, bounded
    # ------------------------------------------------------------
    if ($Config.CollectMessages) {
        $threshold = [int]$Config.MessageSeverityThreshold

        Collect-Query "event_messages" "04_messages" "SSISDB" @"
    WITH E AS ($execScope)
    SELECT TOP (20000)
           m.operation_id AS execution_id, m.event_message_id,
           m.message_time, m.message_type, m.message_source_type,
           m.package_name, m.event_name, m.message_source_name,
           m.message_source_id, m.subcomponent_name,
           m.package_path, m.execution_path, m.message
    FROM catalog.event_messages m
    JOIN E ON m.operation_id=E.execution_id
    WHERE m.message_type >= $threshold
       OR m.event_name IN ('OnError','OnWarning','OnTaskFailed','OnInformation','Diagnostic')
    ORDER BY m.operation_id DESC,m.message_time;
"@

        Collect-Query "operation_messages" "04_messages" "SSISDB" @"
    WITH E AS ($execScope)
    SELECT TOP (20000)
           m.operation_id AS execution_id, m.message_time,
           m.message_type, m.message_source_type, m.message
    FROM catalog.operation_messages m
    JOIN E ON m.operation_id=E.execution_id
    WHERE m.message_type >= $threshold
    ORDER BY m.operation_id DESC,m.message_time;
"@
    }
    else {
        Write-Log "INFO" "Message collection disabled."
    }

}
else {
    Write-Log "INFO" "SSISDB runtime collection disabled."
}

# ------------------------------------------------------------
# Optional additional evidence (only non-overlapping outputs)
# ------------------------------------------------------------
if ($Config.CollectAdditionalEvidence -and $Config.CollectRuntime) {
    $additionalDir = Join-Path $OutputPath "06_additional_evidence"
    $agentDir = Join-Path $additionalDir "sql_agent"
    $wrapperDir = Join-Path $additionalDir "wrapper_references"
    New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
    New-Item -ItemType Directory -Path $wrapperDir -Force | Out-Null

    $additionalWhere = @()
    if ($windowStart) { $additionalWhere += "e.start_time >= CONVERT(datetime, '" + $windowStart.ToString("yyyy-MM-ddTHH:mm:ss") + "', 126)" }
    if ($windowEnd) { $additionalWhere += "e.start_time < CONVERT(datetime, '" + $windowEnd.ToString("yyyy-MM-ddTHH:mm:ss") + "', 126)" }
    if (!$windowStart -and !$windowEnd) { $additionalWhere += "e.start_time >= DATEADD(day,-$([int]$Config.LookbackDays),GETDATE())" }
    foreach ($additionalFilter in @(
        (Build-InFilter "e.folder_name" $Config.FolderNames),
        (Build-InFilter "e.project_name" $Config.ProjectNames),
        (Build-InFilter "e.package_name" $Config.PackageNames)
    )) {
        if ($additionalFilter) { $additionalWhere += $additionalFilter.Substring(5) }
    }
    $additionalWhere = @($additionalWhere | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $additionalWhereSql = ($additionalWhere -join " AND ")

    $commandRedacted = "CAST(REPLACE(REPLACE(REPLACE(REPLACE(js.command, 'Password=', 'Password=[REDACTED]'), 'password=', 'password=[REDACTED]'), 'Pwd=', 'Pwd=[REDACTED]'), 'pwd=', 'pwd=[REDACTED]') AS nvarchar(max))"
    $definitionRedacted = "CAST(REPLACE(REPLACE(REPLACE(REPLACE(m.definition, 'Password=', 'Password=[REDACTED]'), 'password=', 'password=[REDACTED]'), 'Pwd=', 'Pwd=[REDACTED]'), 'pwd=', 'pwd=[REDACTED]') AS nvarchar(max))"

    # These A-section outputs are also the source for candidate mapping.
    Collect-Query "01_sql_agent_job_steps" "06_additional_evidence\sql_agent" "msdb" @"
SELECT j.job_id, j.name AS job_name, j.enabled AS job_enabled,
       js.step_id, js.step_name, js.subsystem, js.database_name,
       $commandRedacted AS command_redacted,
       js.on_success_action, js.on_fail_action, js.retry_attempts,
       js.retry_interval, js.last_run_outcome
FROM dbo.sysjobs AS j
INNER JOIN dbo.sysjobsteps AS js ON js.job_id=j.job_id
ORDER BY j.name, js.step_id;
"@

    Collect-Query "02_sql_agent_job_history" "06_additional_evidence\sql_agent" "msdb" @"
;WITH H AS
(
    SELECT j.job_id, j.name AS job_name, h.instance_id, h.step_id,
           js.step_name, js.subsystem, $commandRedacted AS command_redacted,
           h.run_status,
           CASE h.run_status WHEN 0 THEN 'Failed' WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress' ELSE 'Unknown' END AS run_status_desc,
           h.run_date, h.run_time, h.run_duration, ca.step_start_time,
           DATEADD(SECOND, (h.run_duration / 10000) * 3600
             + ((h.run_duration % 10000) / 100) * 60
             + (h.run_duration % 100), ca.step_start_time) AS step_end_time,
           h.message
    FROM dbo.sysjobhistory AS h
    INNER JOIN dbo.sysjobs AS j ON j.job_id=h.job_id
    LEFT JOIN dbo.sysjobsteps AS js ON js.job_id=h.job_id AND js.step_id=h.step_id
    CROSS APPLY (SELECT DATETIMEFROMPARTS(h.run_date / 10000,
        (h.run_date % 10000) / 100, h.run_date % 100,
        h.run_time / 10000, (h.run_time % 10000) / 100,
        h.run_time % 100, 0) AS step_start_time) AS ca
    WHERE h.run_date >= 19000101
)
SELECT * FROM H
WHERE step_start_time < CONVERT(datetime, '" + $(if ($windowEnd) { $windowEnd.ToString("yyyy-MM-ddTHH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") }) + "', 126)
  AND step_end_time >= CONVERT(datetime, '" + $(if ($windowStart) { $windowStart.ToString("yyyy-MM-ddTHH:mm:ss") } else { (Get-Date).AddDays(-[int]$Config.LookbackDays).ToString("yyyy-MM-ddTHH:mm:ss") }) + "', 126)
ORDER BY step_start_time, job_name, step_id;
"@

    Collect-Query "03_sql_agent_job_schedules" "06_additional_evidence\sql_agent" "msdb" @"
SELECT j.job_id, j.name AS job_name, j.enabled AS job_enabled,
       s.schedule_id, s.name AS schedule_name, s.enabled AS schedule_enabled,
       s.freq_type, s.freq_interval, s.freq_subday_type, s.freq_subday_interval,
       s.freq_relative_interval, s.freq_recurrence_factor,
       s.active_start_date, s.active_start_time, s.active_end_date,
       s.active_end_time, js.next_run_date, js.next_run_time
FROM dbo.sysjobs AS j
LEFT JOIN dbo.sysjobschedules AS js ON js.job_id=j.job_id
LEFT JOIN dbo.sysschedules AS s ON s.schedule_id=js.schedule_id
ORDER BY j.name, s.name;
"@

    Collect-Query "04_candidate_job_package_mapping" "06_additional_evidence\sql_agent" "SSISDB" @"
;WITH JH AS
(
    SELECT j.job_id, j.name AS job_name, h.instance_id, h.step_id,
           js.step_name, js.subsystem, $commandRedacted AS command_redacted,
           h.run_status,
           CASE h.run_status WHEN 0 THEN 'Failed' WHEN 1 THEN 'Succeeded'
                WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled'
                WHEN 4 THEN 'In Progress' ELSE 'Unknown' END AS run_status_desc,
           ca.start_time,
           DATEADD(SECOND, (h.run_duration / 10000) * 3600
             + ((h.run_duration % 10000) / 100) * 60
             + (h.run_duration % 100), ca.start_time) AS end_time
    FROM msdb.dbo.sysjobhistory AS h
    INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id=h.job_id
    INNER JOIN msdb.dbo.sysjobsteps AS js ON js.job_id=h.job_id AND js.step_id=h.step_id
    CROSS APPLY (SELECT DATETIMEFROMPARTS(h.run_date / 10000,
        (h.run_date % 10000) / 100, h.run_date % 100,
        h.run_time / 10000, (h.run_time % 10000) / 100,
        h.run_time % 100, 0) AS start_time) AS ca
    WHERE h.step_id > 0 AND h.run_date >= 19000101
)
SELECT e.execution_id, e.folder_name, e.project_name, e.package_name,
       e.start_time AS ssis_start_time, e.end_time AS ssis_end_time,
       e.status AS ssis_status, jh.job_id, jh.job_name, jh.step_id,
       jh.step_name, jh.subsystem, jh.start_time AS agent_step_start_time,
       jh.end_time AS agent_step_end_time, jh.run_status,
       jh.run_status_desc, jh.instance_id, jh.command_redacted,
       CASE WHEN LOWER(jh.command_redacted) LIKE '%' + LOWER(e.package_name) + '%'
              OR LOWER(jh.step_name)=LOWER(REPLACE(e.package_name,'.dtsx',''))
            THEN 'STRONG_NAME_OR_COMMAND_MATCH' ELSE 'TIME_OVERLAP_ONLY' END AS candidate_match_type
FROM catalog.executions AS e
INNER JOIN JH AS jh ON jh.start_time <= e.start_time AND jh.end_time >= e.end_time
WHERE $additionalWhereSql
ORDER BY e.start_time, e.execution_id, candidate_match_type DESC, jh.job_name, jh.step_id;
"@

    # D01 is not collected by the core collector. D02/D03 are intentionally
    # omitted because the core Query Store module already collects equivalent
    # per-database ranking evidence when enabled.
    Collect-Query "05_query_store_database_state" "06_additional_evidence" "master" @"
SELECT name AS database_name, state_desc, is_read_only, recovery_model_desc,
       compatibility_level, is_query_store_on
FROM sys.databases WHERE state_desc='ONLINE' ORDER BY name;
"@

    if (@($Config.AdditionalEvidenceDatabases).Count -gt 0) {
        foreach ($db in @($Config.AdditionalEvidenceDatabases)) {
            $safeDb = ($db -replace '[^A-Za-z0-9_.-]','_')
            Collect-Query ("06_wrapper_references_" + $safeDb) "06_additional_evidence\wrapper_references" $db @"
SELECT DB_NAME() AS database_name, SCHEMA_NAME(o.schema_id) AS schema_name,
       o.name AS object_name, o.type_desc, $definitionRedacted AS definition_redacted
FROM sys.objects AS o
INNER JOIN sys.sql_modules AS m ON m.object_id=o.object_id
WHERE m.definition LIKE '%SSISDB%'
   OR m.definition LIKE '%catalog.create_execution%'
   OR m.definition LIKE '%dtexec%'
ORDER BY schema_name, object_name;
"@
        }
    }
    else {
        Write-Log "INFO" "Wrapper reference collection skipped: AdditionalEvidenceDatabases is empty."
    }
}
elseif ($Config.CollectAdditionalEvidence -and !$Config.CollectRuntime) {
    Write-Log "INFO" "Additional evidence skipped because runtime collection is disabled."
}
else {
    Write-Log "INFO" "Additional evidence collection disabled."
}

# ------------------------------------------------------------
# Optional Query Store evidence
# ------------------------------------------------------------
if ($Config.CollectQueryStore -and $Config.QueryStoreDatabases -and @($Config.QueryStoreDatabases).Count -gt 0) {
    foreach ($db in @($Config.QueryStoreDatabases)) {
        $safe = ($db -replace '[^A-Za-z0-9_.-]','_')

        Collect-Query ("querystore_top_duration_" + $safe) "05_sqlserver_optional" $db @"
SELECT TOP (100)
       q.query_id, qt.query_sql_text,
       SUM(rs.count_executions) AS execution_count,
       CAST(SUM(rs.avg_duration * rs.count_executions)/NULLIF(SUM(rs.count_executions),0)/1000.0 AS decimal(18,2)) AS weighted_avg_duration_ms,
       CAST(MAX(rs.max_duration)/1000.0 AS decimal(18,2)) AS max_duration_ms,
       MAX(rs.last_execution_time) AS last_execution_time
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id=q.query_text_id
JOIN sys.query_store_plan p ON q.query_id=p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id=rs.plan_id
GROUP BY q.query_id,qt.query_sql_text
ORDER BY weighted_avg_duration_ms DESC;
"@

        Collect-Query ("querystore_top_logical_io_" + $safe) "05_sqlserver_optional" $db @"
SELECT TOP (100)
       q.query_id, qt.query_sql_text,
       SUM(rs.count_executions) AS execution_count,
       CAST(SUM(rs.avg_logical_io_reads * rs.count_executions)/NULLIF(SUM(rs.count_executions),0) AS decimal(18,2)) AS weighted_avg_logical_reads,
       MAX(rs.last_execution_time) AS last_execution_time
FROM sys.query_store_query_text qt
JOIN sys.query_store_query q ON qt.query_text_id=q.query_text_id
JOIN sys.query_store_plan p ON q.query_id=p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id=rs.plan_id
GROUP BY q.query_id,qt.query_sql_text
ORDER BY weighted_avg_logical_reads DESC;
"@
    }
}
else {
    Write-Log "INFO" "Query Store collection disabled or no QueryStoreDatabases configured."
}

# ------------------------------------------------------------
# Evidence manifest
# ------------------------------------------------------------
$evidenceFiles = Get-ChildItem -Path $OutputPath -Recurse | Where-Object { -not $_.PSIsContainer -and $_.Name -ne "collector.log" } | ForEach-Object {
    New-Object PSObject -Property @{
        RelativePath = $_.FullName.Substring($OutputPath.TrimEnd([char[]]@(92,47)).Length).TrimStart([char[]]@(92,47))
        SizeBytes = $_.Length
        LastWriteTime = $_.LastWriteTime
    }
}
$evidenceFiles | Export-Csv (Join-Path $manifestDir "evidence_manifest.csv") -NoTypeInformation -Encoding UTF8

Write-Log "INFO" "Collector finished."
