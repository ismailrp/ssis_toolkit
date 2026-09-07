$history = Import-Csv .\queries\02_sql_agent_job_history.csv | Where-Object { [int]$_.step_id -gt 0 }
$steps = @{}
foreach ($row in (Import-Csv .\queries\01_sql_agent_job_steps.csv)) {
    $steps["$($row.job_id)|$($row.step_id)"] = $row
}
$executions = @{}
foreach ($row in (Import-Csv .\queries\04_ssis_executions.csv)) {
    $executions[$row.execution_id] = $row
}
$findings = @{}
foreach ($row in (Import-Csv .\DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv)) {
    $findings[$row.PackageFile] = $row
}

$mapped = foreach ($row in $history) {
    $match = [regex]::Match([string]$row.message, 'Execution ID:\s*(\d+)')
    if (!$match.Success) { continue }
    $executionId = $match.Groups[1].Value
    if (!$executions.ContainsKey($executionId)) { continue }
    $step = $steps["$($row.job_id)|$($row.step_id)"]
    if (!$step -or [int]$step.job_enabled -ne 1) { continue }
    $execution = $executions[$executionId]
    $key = "SSISDB/$($execution.folder_name)/$($execution.project_name)/$($execution.package_name)"
    $finding = $findings[$key]
    if (!$finding) { continue }
    $adoProviderCount = [int]($finding | Select-Object -ExpandProperty 'ADO.NET_or_ODBC_Provider')
    [pscustomobject]@{
        job_id = $row.job_id; job_name = $row.job_name; step_id = $row.step_id; step_name = $row.step_name
        folder_name = $execution.folder_name; project_name = $execution.project_name; package_name = $execution.package_name
        package_duration_sec = [double]$execution.duration_ms / 1000; ssis_status = $execution.status_desc
        execution_id = $executionId; job_step_start_time = $row.start_time; job_step_end_time = $row.end_time
        anti_sort = [int]$finding.Sort; anti_aggregate = [int]$finding.Aggregate; anti_fuzzy_lookup = [int]$finding.FuzzyLookup
        anti_fast_load_inactive = [int]$finding.FastLoadInactive; anti_no_tablock = [int]$finding.NoTABLOCK
        anti_lookup_partial_no_cache = [int]$finding.LookupPartialNoCache; anti_select_star = [int]$finding.'SELECT*'; anti_oledb_command = [int]$finding.OLEDBCommand
        CartesianCrossJoin = [int]$finding.CartesianCrossJoin; NonSargableFunctionPredicate = [int]$finding.NonSargableFunctionPredicate; OnTheFlyFunctionExpression = [int]$finding.OnTheFlyFunctionExpression; NestedViewReference = [int]$finding.NestedViewReference; PivotWindowFunction = [int]$finding.PivotWindowFunction; UnionAll = [int]$finding.UnionAll; NoLockAdvisory = [int]$finding.NoLockAdvisory; MergeJoinComponent = [int]$finding.MergeJoinComponent; ImplicitConversionIndicator = [int]$finding.ImplicitConversionIndicator; ScriptComponent = [int]$finding.ScriptComponent; ADO_NET_or_ODBC_Provider = $adoProviderCount; ExplicitBufferOrThreadSetting = [int]$finding.ExplicitBufferOrThreadSetting; TempStoragePathSetting = [int]$finding.TempStoragePathSetting; DestinationCommitSizeSetting = [int]$finding.DestinationCommitSizeSetting; ExecutePackageTask = [int]$finding.ExecutePackageTask; CheckpointSetting = [int]$finding.CheckpointSetting; FullReloadIndicator = [int]$finding.FullReloadIndicator
    }
}

$groups = $mapped | Group-Object job_id,job_name,step_id,step_name,folder_name,project_name,package_name
$report = foreach ($group in $groups) {
    $rows = $group.Group
    $first = $rows[0]
    $avgSec = (($rows | Measure-Object package_duration_sec -Average).Average)
    $totalSec = (($rows | Measure-Object package_duration_sec -Sum).Sum)
    $failed = @($rows | Where-Object { $_.ssis_status -ne 'Succeeded' }).Count
    $antiTotal = @($first.anti_sort,$first.anti_aggregate,$first.anti_fuzzy_lookup,$first.anti_fast_load_inactive,$first.anti_no_tablock,$first.anti_lookup_partial_no_cache,$first.anti_select_star,$first.anti_oledb_command,$first.CartesianCrossJoin,$first.NonSargableFunctionPredicate,$first.OnTheFlyFunctionExpression,$first.NestedViewReference,$first.PivotWindowFunction,$first.UnionAll,$first.NoLockAdvisory,$first.MergeJoinComponent,$first.ImplicitConversionIndicator,$first.ScriptComponent,$first.'ADO.NET_or_ODBC_Provider',$first.ExplicitBufferOrThreadSetting,$first.TempStoragePathSetting,$first.DestinationCommitSizeSetting,$first.ExecutePackageTask,$first.CheckpointSetting,$first.FullReloadIndicator) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    if ($failed -gt 0 -or $avgSec -ge 1800 -or $totalSec -ge 7200) {
        $priority = 'P1'; $priorityBasis = 'High runtime or reliability impact'
    } elseif ($avgSec -ge 600 -or $antiTotal -ge 10) {
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
        CartesianCrossJoin = $first.CartesianCrossJoin; NonSargableFunctionPredicate = $first.NonSargableFunctionPredicate; OnTheFlyFunctionExpression = $first.OnTheFlyFunctionExpression; NestedViewReference = $first.NestedViewReference; PivotWindowFunction = $first.PivotWindowFunction; UnionAll = $first.UnionAll; NoLockAdvisory = $first.NoLockAdvisory; MergeJoinComponent = $first.MergeJoinComponent; ImplicitConversionIndicator = $first.ImplicitConversionIndicator; ScriptComponent = $first.ScriptComponent; ADO_NET_or_ODBC_Provider = $first.'ADO.NET_or_ODBC_Provider'; ExplicitBufferOrThreadSetting = $first.ExplicitBufferOrThreadSetting; TempStoragePathSetting = $first.TempStoragePathSetting; DestinationCommitSizeSetting = $first.DestinationCommitSizeSetting; ExecutePackageTask = $first.ExecutePackageTask; CheckpointSetting = $first.CheckpointSetting; FullReloadIndicator = $first.FullReloadIndicator
        priority_level = $priority; priority_basis = $priorityBasis
    }
}
$report = @($report | Sort-Object avg_package_duration_sec -Descending)
$report | Export-Csv .\ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY.csv -NoTypeInformation -Encoding UTF8

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Active SQL Agent Job / SSIS Anti-Pattern Priority Report')
$lines.Add('')
$lines.Add('Scope: only SQL Agent jobs with `job_enabled = 1`. Mapping uses the SSIS `Execution ID` embedded in SQL Agent history messages, then joins to `04_ssis_executions.csv` and `DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv`. `TIME_OVERLAP_ONLY` candidates are excluded.')
$lines.Add('')
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("Mapped active job-step/package groups: $($report.Count)")
$lines.Add('')
$lines.Add('| Rank | Priority | Job | Step | Package | Executions | Avg min | Max min | Total hours | Failed | Anti-patterns |')
$lines.Add('|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|')
$rank = 0
foreach ($row in $report) {
    $rank++
    $anti = @($row.anti_sort,$row.anti_aggregate,$row.anti_fuzzy_lookup,$row.anti_fast_load_inactive,$row.anti_no_tablock,$row.anti_lookup_partial_no_cache,$row.anti_select_star,$row.anti_oledb_command,$row.CartesianCrossJoin,$row.NonSargableFunctionPredicate,$row.OnTheFlyFunctionExpression,$row.NestedViewReference,$row.PivotWindowFunction,$row.UnionAll,$row.NoLockAdvisory,$row.MergeJoinComponent,$row.ImplicitConversionIndicator,$row.ScriptComponent,$row.ADO_NET_or_ODBC_Provider,$row.ExplicitBufferOrThreadSetting,$row.TempStoragePathSetting,$row.DestinationCommitSizeSetting,$row.ExecutePackageTask,$row.CheckpointSetting,$row.FullReloadIndicator) | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $lines.Add("| $rank | $($row.priority_level) | $($row.job_name) | $($row.step_id): $($row.step_name) | $($row.package_name) | $($row.execution_count) | $([math]::Round($row.avg_package_duration_sec / 60,1)) | $([math]::Round($row.max_package_duration_sec / 60,1)) | $([math]::Round($row.total_package_duration_sec / 3600,1)) | $($row.failed_or_unexpected_count) | $anti |")
}
$lines.Add('')
$lines.Add('## Interpretation')
$lines.Add('')
$lines.Add('- Prioritize by average package duration first, then execution frequency and anti-pattern count.')
$lines.Add('- Priority rule: P1 = any failure, average duration >= 30 minutes, or mapped cumulative duration >= 2 hours; P2 = average duration >= 10 minutes or at least 10 static findings; P3 = otherwise. P0 is not assigned automatically.')
$lines.Add('- Job/step mapping is high confidence where the SQL Agent history message contains the matching SSIS `Execution ID`.')
$lines.Add('- Package duration is SSIS execution duration; job-step duration includes SQL Agent overhead and should be used for end-to-end validation.')
$lines.Add('- This report does not include disabled jobs and does not treat time-overlap-only candidates as confirmed mappings.')
[System.IO.File]::WriteAllLines('.\ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY.md', $lines, [System.Text.UTF8Encoding]::new($false))
