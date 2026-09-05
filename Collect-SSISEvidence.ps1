# PATCH-ID: NETZIP-NOREGRESSION-20260902-v1.1.7
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [Parameter(Mandatory=$true)][string]$OutputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. $ConfigPath

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
    CollectStatic = $Config.CollectStatic
    CollectRuntime = $Config.CollectRuntime
    IspacRoot = $Config.IspacRoot
    CollectMessages = $Config.CollectMessages
    CollectQueryStore = $Config.CollectQueryStore
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
    $executionWhere = "WHERE start_time >= DATEADD(day,-$lookback,GETDATE()) $folderFilter $projectFilter $packageFilter"

    Collect-Query "executions" "03_runtime" "SSISDB" @"
    SELECT TOP ($maxExec)
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
    SELECT TOP ($maxExec) execution_id
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
