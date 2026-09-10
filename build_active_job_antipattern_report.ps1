param(
    [string]$AssessmentPath = ".",
    [string]$OutputPath = ".",
    [string]$StaticFindingsPath = "",
    [string]$ReportSuffix = "",
    [string]$MismatchOutputPath = "",
    [switch]$IncludeCommandTimeCandidates,
    [int]$CandidateToleranceSeconds = 60,
    [string]$CandidateOutputPath = ""
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$assessmentRoot = (Resolve-Path -LiteralPath $AssessmentPath).Path
$outputRoot = (Resolve-Path -LiteralPath $OutputPath).Path
$isAssessment = (Test-Path (Join-Path $assessmentRoot "06_additional_evidence\sql_agent\02_sql_agent_job_history.csv"))
if ($isAssessment) {
    $historyPath = Join-Path $assessmentRoot "06_additional_evidence\sql_agent\02_sql_agent_job_history.csv"
    $stepsPath = Join-Path $assessmentRoot "06_additional_evidence\sql_agent\01_sql_agent_job_steps.csv"
    $executionsPath = Join-Path $assessmentRoot "03_runtime\executions.csv"
    if ([string]::IsNullOrWhiteSpace($StaticFindingsPath)) {
        $StaticFindingsPath = Join-Path $assessmentRoot "01_static_packages\package_static_summary.csv"
    }
}
else {
    $historyPath = Join-Path $assessmentRoot "queries\02_sql_agent_job_history.csv"
    $stepsPath = Join-Path $assessmentRoot "queries\01_sql_agent_job_steps.csv"
    $executionsPath = Join-Path $assessmentRoot "queries\04_ssis_executions.csv"
    if ([string]::IsNullOrWhiteSpace($StaticFindingsPath)) {
        $StaticFindingsPath = Join-Path $assessmentRoot "DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv"
    }
}

$historyStartField = if ($isAssessment) { 'step_start_time' } else { 'start_time' }
$historyEndField = if ($isAssessment) { 'step_end_time' } else { 'end_time' }
$outputName = "ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY"
if ($ReportSuffix) { $outputName += "_" + $ReportSuffix }
if ([string]::IsNullOrWhiteSpace($MismatchOutputPath)) {
    $MismatchOutputPath = Join-Path $outputRoot ($outputName + "_MAPPING_MISMATCH.csv")
}
if ([string]::IsNullOrWhiteSpace($CandidateOutputPath)) {
    $CandidateOutputPath = Join-Path $outputRoot ($outputName + "_COMMAND_TIME_CANDIDATES.csv")
}

$history = Import-Csv $historyPath | Where-Object { [int]$_.step_id -gt 0 }
$steps = @{}
foreach ($row in (Import-Csv $stepsPath)) {
    $steps["$($row.job_id)|$($row.step_id)"] = $row
}
$executions = @{}
foreach ($row in (Import-Csv $executionsPath)) {
    $executions[$row.execution_id] = $row
}
$executionByPackage = @{}
foreach ($execution in $executions.Values) {
    $executionKey = "{0}/{1}/{2}" -f $execution.folder_name,$execution.project_name,$execution.package_name
    if (!$executionByPackage.ContainsKey($executionKey)) { $executionByPackage[$executionKey] = New-Object System.Collections.ArrayList }
    $candidateRow = [pscustomobject]@{ execution_id=$execution.execution_id; folder_name=$execution.folder_name; project_name=$execution.project_name; package_name=$execution.package_name; start_time=$execution.start_time; end_time=$execution.end_time; start_dt=[datetime]::Parse([string]$execution.start_time); end_dt=[datetime]::Parse([string]$execution.end_time) }
    [void]$executionByPackage[$executionKey].Add($candidateRow)
}
$findings = @{}
$antiPatternColumns = @('Sort','Aggregate','FuzzyLookup','FuzzyGrouping','LookupPartialNoCache','MergeComponent','MergeJoinComponent','ConditionalSplitFilter','DataConversionComponent','OLEDBCommand','ScriptComponent','FastLoadInactive','NoTABLOCK','DestinationCommitSizeSetting','SELECT*','CartesianCrossJoin','ImplicitCartesianJoin','NonSargableFunctionPredicate','OnTheFlyFunctionExpression','NestedViewReference','PivotWindowFunction','SqlUnionDistinct','FullReloadIndicator','ADO_NET_or_ODBC_Provider','DelayValidationDisabled','ValidateExternalMetadataEnabled','CheckpointDisabled','TransactionEnabled','MonolithicPackage')
foreach ($row in (Import-Csv $StaticFindingsPath)) {
    if ($row.PSObject.Properties.Name -contains 'PackageFile') {
        $findings[$row.PackageFile] = $row
    }
    else {
        $key = "SSISDB/$($row.FolderName)/$($row.ProjectName)/$($row.PackageName)"
        $findings[$key] = [pscustomobject]@{
            PackageFile = $key
            Sort = if ($row.HasSortIndicator -eq 'True') { 1 } else { 0 }
            Aggregate = if ($row.HasAggregateIndicator -eq 'True') { 1 } else { 0 }
            FuzzyLookup = $null
            FastLoadInactive = $null
            NoTABLOCK = $null
            LookupPartialNoCache = $null
            'SELECT*' = $null
            OLEDBCommand = $null
            CartesianCrossJoin = $null
            NonSargableFunctionPredicate = $null
            OnTheFlyFunctionExpression = $null
            NestedViewReference = $null
            PivotWindowFunction = $null
            UnionAll = $null
            NoLockAdvisory = $null
            MergeJoinComponent = if ($row.HasMergeIndicator -eq 'True') { 1 } else { 0 }
            ImplicitConversionIndicator = $null
            ScriptComponent = if ($row.HasScriptIndicator -eq 'True') { 1 } else { 0 }
            'ADO.NET_or_ODBC_Provider' = $null
            ExplicitBufferOrThreadSetting = $null
            TempStoragePathSetting = $null
            DestinationCommitSizeSetting = $null
            ExecutePackageTask = $null
             CheckpointSetting = $null
             FullReloadIndicator = $null
             anti_pattern_components = $null
        }
    }
}
function Get-AntiPatternInfo([object]$finding) {
    $count = 0; $names = New-Object System.Collections.Generic.List[string]
    if ($finding) {
        foreach ($column in $antiPatternColumns) {
            if ($finding.PSObject.Properties[$column] -and [int]$finding.$column -gt 0) { $count += [int]$finding.$column; [void]$names.Add($column) }
        }
    }
    $components=''
    if($finding -and $finding.PSObject.Properties['anti_pattern_components']){$components=[string]$finding.anti_pattern_components}
    return [pscustomobject]@{ Count=$count; RuleCount=$names.Count; Fields=($names -join ';'); Components=$components }
}
function Get-ProvisionalPriority([double]$durationSeconds, [string]$status) {
    if ($status -ne '1' -and $status -ne 'Succeeded') { return [pscustomobject]@{ Level='P1'; Basis='PROVISIONAL_JOB_STEP_FAILURE' } }
    if ($durationSeconds -ge 1800) { return [pscustomobject]@{ Level='P1'; Basis='PROVISIONAL_JOB_STEP_DURATION_GE_30_MIN' } }
    if ($durationSeconds -ge 600) { return [pscustomobject]@{ Level='P2'; Basis='PROVISIONAL_JOB_STEP_DURATION_GE_10_MIN' } }
    return [pscustomobject]@{ Level='P3'; Basis='PROVISIONAL_JOB_STEP_DURATION_LT_10_MIN' }
}

$mismatches = @()
$candidates = @()
$mapped = foreach ($row in $history) {
    $match = [regex]::Match([string]$row.message, 'Execution ID:\s*(\d+)')
    if (!$match.Success) { continue }
    $executionId = $match.Groups[1].Value
    if (!$executions.ContainsKey($executionId)) { continue }
    $step = $steps["$($row.job_id)|$($row.step_id)"]
    if (!$step -or [int]$step.job_enabled -ne 1) { continue }
    $execution = $executions[$executionId]
    $key = "SSISDB/$($execution.folder_name)/$($execution.project_name)/$($execution.package_name)"
    $commandMatch = [regex]::Match([string]$row.command_redacted, '(?i)\\SSISDB\\(?<path>[^\"]+?\.dtsx)')
    if ($commandMatch.Success) {
        $commandKey = ("SSISDB/" + $commandMatch.Groups['path'].Value).Replace('\', '/')
        $executionKey = $key.Replace('\', '/')
        if ($commandKey -ne $executionKey) {
            $commandFinding = $findings[$commandKey]
            $commandAnti = Get-AntiPatternInfo $commandFinding
            $jobStepStart = [datetime]::Parse([string]$row.($historyStartField))
            $jobStepEnd = [datetime]::Parse([string]$row.($historyEndField))
            $jobStepDuration = ($jobStepEnd - $jobStepStart).TotalSeconds
            $provisional = Get-ProvisionalPriority $jobStepDuration ([string]$row.run_status_desc)
            if ($IncludeCommandTimeCandidates) {
                $commandParts = $commandKey.Substring(7).Split('/')
                $commandFolder = $commandParts[0]; $commandProject = $commandParts[1]; $commandPackage = ($commandParts[2..($commandParts.Count - 1)] -join '/')
                $stepStart = $jobStepStart
                $stepEnd = $jobStepEnd
                $candidateKey = "{0}/{1}/{2}" -f $commandFolder,$commandProject,$commandPackage
                $possible = @()
                if ($executionByPackage.ContainsKey($candidateKey)) {
                    $possible = @($executionByPackage[$candidateKey] | Where-Object {
                        $_.start_dt -le $stepEnd.AddSeconds($CandidateToleranceSeconds) -and $_.end_dt -ge $stepStart.AddSeconds(-$CandidateToleranceSeconds)
                    })
                }
                foreach ($candidate in $possible) {
                    $candidates += [pscustomobject]@{
                        execution_id = $candidate.execution_id; job_id = $row.job_id; job_name = $row.job_name; step_id = $row.step_id; step_name = $row.step_name
                        command_package = $commandKey; candidate_package = ("SSISDB/{0}/{1}/{2}" -f $candidate.folder_name,$candidate.project_name,$candidate.package_name)
                        command_start_time = $row.($historyStartField); command_end_time = $row.($historyEndField); job_step_duration_sec = [math]::Round($jobStepDuration,2); job_step_status = $row.run_status_desc; execution_start_time = $candidate.start_time; execution_end_time = $candidate.end_time
                        candidate_count = $possible.Count; confidence = if ($possible.Count -eq 1) { 'COMMAND_TIME_CANDIDATE' } else { 'AMBIGUOUS_TIME_OVERLAP' }; priority_level = $provisional.Level; priority_confidence = 'PROVISIONAL_JOB_STEP'; priority_basis = $provisional.Basis; anti_pattern_count = $commandAnti.Count; anti_pattern_rule_count = $commandAnti.RuleCount; anti_pattern_fields = $commandAnti.Fields; anti_pattern_components = $commandAnti.Components
                    }
                }
            }
            $mismatches += [pscustomobject]@{
                execution_id = $executionId; job_id = $row.job_id; job_name = $row.job_name; step_id = $row.step_id; step_name = $row.step_name
                command_package = $commandKey; execution_package = $executionKey; job_step_start_time = $row.($historyStartField); job_step_end_time = $row.($historyEndField); job_step_duration_sec = [math]::Round($jobStepDuration,2); job_step_status = $row.run_status_desc; priority_level = $provisional.Level; priority_confidence = 'PROVISIONAL_JOB_STEP'; priority_basis = $provisional.Basis; anti_pattern_count = $commandAnti.Count; anti_pattern_rule_count = $commandAnti.RuleCount; anti_pattern_fields = $commandAnti.Fields; anti_pattern_components = $commandAnti.Components; reason = 'SQL Agent command package differs from package recorded for the same SSIS Execution ID'
            }
            continue
        }
    }
    $finding = $findings[$key]
    if (!$finding) { continue }
    $antiInfo = Get-AntiPatternInfo $finding
    $adoProviderCount = 0
    if ($finding.PSObject.Properties['ADO.NET_or_ODBC_Provider']) { $adoProviderCount = [int]$finding.'ADO.NET_or_ODBC_Provider' }
    elseif ($finding.PSObject.Properties['ADO_NET_or_ODBC_Provider']) { $adoProviderCount = [int]$finding.ADO_NET_or_ODBC_Provider }
    [pscustomobject]@{
        job_id = $row.job_id; job_name = $row.job_name; step_id = $row.step_id; step_name = $row.step_name
        folder_name = $execution.folder_name; project_name = $execution.project_name; package_name = $execution.package_name
        package_duration_sec = [double]$execution.duration_ms / 1000; ssis_status = $execution.status_desc
        execution_id = $executionId; job_step_start_time = $row.($historyStartField); job_step_end_time = $row.($historyEndField)
        anti_sort = [int]$finding.Sort; anti_aggregate = [int]$finding.Aggregate; anti_fuzzy_lookup = [int]$finding.FuzzyLookup
        anti_fast_load_inactive = [int]$finding.FastLoadInactive; anti_no_tablock = [int]$finding.NoTABLOCK
        anti_lookup_partial_no_cache = [int]$finding.LookupPartialNoCache; anti_select_star = [int]$finding.'SELECT*'; anti_oledb_command = [int]$finding.OLEDBCommand
         CartesianCrossJoin = [int]$finding.CartesianCrossJoin; NonSargableFunctionPredicate = [int]$finding.NonSargableFunctionPredicate; OnTheFlyFunctionExpression = [int]$finding.OnTheFlyFunctionExpression; NestedViewReference = [int]$finding.NestedViewReference; PivotWindowFunction = [int]$finding.PivotWindowFunction; UnionAll = [int]$finding.SqlUnionAll; NoLockAdvisory = [int]$finding.NoLockAdvisory; MergeJoinComponent = [int]$finding.MergeJoinComponent; ImplicitConversionIndicator = [int]$finding.DataConversionComponent; ScriptComponent = [int]$finding.ScriptComponent; ADO_NET_or_ODBC_Provider = $adoProviderCount; ExplicitBufferOrThreadSetting = [int]$finding.ExplicitBufferOrThreadSetting; TempStoragePathSetting = [int]$finding.TempStoragePathSetting; DestinationCommitSizeSetting = [int]$finding.DestinationCommitSizeSetting; ExecutePackageTask = [int]$finding.ExecutePackageTask; CheckpointSetting = [int]$finding.CheckpointDisabled; FullReloadIndicator = [int]$finding.FullReloadIndicator; anti_pattern_count = $antiInfo.Count; anti_pattern_rule_count = $antiInfo.RuleCount; anti_pattern_fields = $antiInfo.Fields; anti_pattern_components = [string]$finding.anti_pattern_components
    }
}

$groups = $mapped | Group-Object job_id,job_name,step_id,step_name,folder_name,project_name,package_name
$report = foreach ($group in $groups) {
    $rows = $group.Group
    $first = $rows[0]
    $avgSec = (($rows | Measure-Object package_duration_sec -Average).Average)
    $totalSec = (($rows | Measure-Object package_duration_sec -Sum).Sum)
    $failed = @($rows | Where-Object { $_.ssis_status -ne 'Succeeded' }).Count
    $antiTotal = [int]$first.anti_pattern_count
    $antiRuleCount = [int]$first.anti_pattern_rule_count
    if ($failed -gt 0 -or $avgSec -ge 1800 -or $totalSec -ge 7200) {
        $priority = 'P1'; $priorityBasis = 'High runtime or reliability impact'
    } elseif ($avgSec -ge 600 -or $antiRuleCount -ge 10) {
        $priority = 'P2'; $priorityBasis = 'Material optimization/investigation candidate'
    } else {
        $priority = 'P3'; $priorityBasis = 'Lower-impact or static-only optimization candidate'
    }
    [pscustomobject]@{
        job_id = $first.job_id; job_name = $first.job_name; step_id = $first.step_id; step_name = $first.step_name
        folder_name = $first.folder_name; project_name = $first.project_name; package_name = $first.package_name
        execution_count = $rows.Count
        avg_package_duration_sec = [math]::Round($avgSec, 2)
        max_package_duration_sec = [math]::Round((($rows | Measure-Object package_duration_sec -Maximum).Maximum), 2)
        total_package_duration_sec = [math]::Round($totalSec, 2)
        succeeded_count = @($rows | Where-Object { $_.ssis_status -eq 'Succeeded' }).Count
        failed_or_unexpected_count = @($rows | Where-Object { $_.ssis_status -ne 'Succeeded' }).Count
        anti_sort = $first.anti_sort; anti_aggregate = $first.anti_aggregate; anti_fuzzy_lookup = $first.anti_fuzzy_lookup
        anti_fast_load_inactive = $first.anti_fast_load_inactive; anti_no_tablock = $first.anti_no_tablock
        anti_lookup_partial_no_cache = $first.anti_lookup_partial_no_cache; anti_select_star = $first.anti_select_star; anti_oledb_command = $first.anti_oledb_command
        CartesianCrossJoin = $first.CartesianCrossJoin; NonSargableFunctionPredicate = $first.NonSargableFunctionPredicate; OnTheFlyFunctionExpression = $first.OnTheFlyFunctionExpression; NestedViewReference = $first.NestedViewReference; PivotWindowFunction = $first.PivotWindowFunction; UnionAll = $first.UnionAll; NoLockAdvisory = $first.NoLockAdvisory; MergeJoinComponent = $first.MergeJoinComponent; ImplicitConversionIndicator = $first.ImplicitConversionIndicator; ScriptComponent = $first.ScriptComponent; ADO_NET_or_ODBC_Provider = $first.ADO_NET_or_ODBC_Provider; ExplicitBufferOrThreadSetting = $first.ExplicitBufferOrThreadSetting; TempStoragePathSetting = $first.TempStoragePathSetting; DestinationCommitSizeSetting = $first.DestinationCommitSizeSetting; ExecutePackageTask = $first.ExecutePackageTask; CheckpointSetting = $first.CheckpointSetting; FullReloadIndicator = $first.FullReloadIndicator
         anti_pattern_count = $antiTotal; anti_pattern_rule_count = $antiRuleCount; anti_pattern_fields = $first.anti_pattern_fields
         priority_level = $priority; priority_basis = $priorityBasis
         anti_pattern_components = $first.anti_pattern_components
    }
}
$report = @($report | Sort-Object avg_package_duration_sec -Descending)
$csvOutput = Join-Path $outputRoot ($outputName + ".csv")
$mdOutput = Join-Path $outputRoot ($outputName + ".md")
$mismatchFileName = [IO.Path]::GetFileName($MismatchOutputPath)
$report | Export-Csv $csvOutput -NoTypeInformation -Encoding UTF8

$lines = New-Object 'System.Collections.Generic.List[string]'
$lines.Add('# Active SQL Agent Job / SSIS Anti-Pattern Priority Report')
$lines.Add('')
$lines.Add('Scope: only SQL Agent jobs with `job_enabled = 1`. Mapping uses the SSIS `Execution ID` embedded in SQL Agent history messages, then joins to `04_ssis_executions.csv` and `DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv`. `TIME_OVERLAP_ONLY` candidates are excluded.')
$lines.Add('')
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("Mapped active job-step/package groups: $($report.Count)")
$lines.Add(('Excluded Execution ID/package mismatches: {0}; see `{1}`.' -f $mismatches.Count, $mismatchFileName))
$lines.Add(('Command/time candidate mode: {0}; candidate rows: {1}.' -f ([string]$IncludeCommandTimeCandidates), $candidates.Count))
$lines.Add('')
$lines.Add('| Rank | Priority | Job | Step | Package | Executions | Avg min | Max min | Total hours | Failed | Static rules |')
$lines.Add('|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|')
$rank = 0
foreach ($row in $report) {
    $rank++
    $anti = $row.anti_pattern_rule_count
    $lines.Add("| $rank | $($row.priority_level) | $($row.job_name) | $($row.step_id): $($row.step_name) | $($row.package_name) | $($row.execution_count) | $([math]::Round($row.avg_package_duration_sec / 60,1)) | $([math]::Round($row.max_package_duration_sec / 60,1)) | $([math]::Round($row.total_package_duration_sec / 3600,1)) | $($row.failed_or_unexpected_count) | $anti |")
}
$lines.Add('')
$lines.Add('## Interpretation')
$lines.Add('')
$lines.Add('- Prioritize by average package duration first, then execution frequency and anti-pattern count.')
$lines.Add('- Priority rule: P1 = any failure, average duration >= 30 minutes, or mapped cumulative duration >= 2 hours; P2 = average duration >= 10 minutes or at least 10 distinct static candidate rules; P3 = otherwise. Static occurrence volume alone does not raise priority. P0 is not assigned automatically.')
$lines.Add('- Job/step mapping is high confidence where the SQL Agent history message contains the matching SSIS `Execution ID`.')
$lines.Add('- Package duration is SSIS execution duration; job-step duration includes SQL Agent overhead and should be used for end-to-end validation.')
$lines.Add('- This report does not include disabled jobs and does not treat time-overlap-only candidates as confirmed mappings.')
[System.IO.File]::WriteAllLines($mdOutput, $lines, (New-Object System.Text.UTF8Encoding($false)))
$mismatches | Export-Csv $MismatchOutputPath -NoTypeInformation -Encoding UTF8
$candidates | Export-Csv $CandidateOutputPath -NoTypeInformation -Encoding UTF8
Write-Host "Wrote $csvOutput and $mdOutput ($($report.Count) groups); excluded $($mismatches.Count) mapping mismatches to $MismatchOutputPath; candidates=$($candidates.Count) at $CandidateOutputPath"
