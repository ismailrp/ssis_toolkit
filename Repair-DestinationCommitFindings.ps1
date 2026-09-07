Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Join-Path (Get-Location) 'assessments\EVSET-001\01_static_packages\extracted'
$findingsPath = Join-Path (Get-Location) 'DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv'
$runtimePath = Join-Path (Get-Location) 'assessments\EVSET-001\03_runtime\package_runtime_summary.csv'
$outPath = Join-Path (Get-Location) 'RUNTIME_HEAVY_WITHOUT_ANTIPATTERN.csv'

$findings = @(Import-Csv $findingsPath)
foreach ($row in $findings) {
    $path = Join-Path $root ($row.PackageFile.Substring(7).Replace('/','\'))
    if (!(Test-Path -LiteralPath $path)) { continue }
    $text = [IO.File]::ReadAllText($path)
    $risk = 0
    foreach ($m in [regex]::Matches($text, 'name="FastLoadMaxInsertCommitSize">\s*(\d+)\s*</property>', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $value = [int64]$m.Groups[1].Value
        if ($value -gt 0 -and $value -lt 100000) { $risk++ }
    }
    if ($text -match 'name="FastLoadMaxInsertCommitSize">\s*2147483647\s*</property>') {
        $row | Add-Member -MemberType NoteProperty -Name DestinationCommitSizeSetting -Value '0' -Force
    } else {
        $row | Add-Member -MemberType NoteProperty -Name DestinationCommitSizeSetting -Value ([string]$risk) -Force
    }
}
$findings | Export-Csv $findingsPath -NoTypeInformation -Encoding UTF8

$findingColumns = @('Sort','Aggregate','FuzzyLookup','FastLoadInactive','NoTABLOCK','LookupPartialNoCache','SELECT*','OLEDBCommand','CartesianCrossJoin','NonSargableFunctionPredicate','OnTheFlyFunctionExpression','NestedViewReference','PivotWindowFunction','UnionAll','NoLockAdvisory','MergeJoinComponent','ImplicitConversionIndicator','ScriptComponent','ADO.NET_or_ODBC_Provider','ExplicitBufferOrThreadSetting','TempStoragePathSetting','DestinationCommitSizeSetting','ExecutePackageTask','CheckpointSetting','FullReloadIndicator')
$findingMap = @{}
foreach ($row in $findings) { $findingMap[$row.PackageFile.Substring(7)] = $row }
$heavy = foreach ($runtime in (Import-Csv $runtimePath)) {
    if ([double]$runtime.avg_duration_sec -lt 600) { continue }
    $key = "$($runtime.folder_name)/$($runtime.project_name)/$($runtime.package_name)"
    $finding = $findingMap[$key]
    $anti = 0
    if ($finding) {
        foreach ($column in $findingColumns) { $anti += [int]$finding.$column }
    }
    if ($anti -eq 0) {
        [pscustomobject]@{
            folder_name=$runtime.folder_name; project_name=$runtime.project_name; package_name=$runtime.package_name
            executions=$runtime.executions; avg_duration_sec=$runtime.avg_duration_sec; max_duration_sec=$runtime.max_duration_sec
            failed_or_unexpected=$runtime.failed_or_unexpected; last_start_time=$runtime.last_start_time
            reason='Average runtime >= 10 minutes, but no static anti-pattern finding after commit-size correction'
        }
    }
}
$heavy | Sort-Object {[double]$_.avg_duration_sec} -Descending | Export-Csv $outPath -NoTypeInformation -Encoding UTF8
Write-Host "Corrected findings: $($findings.Count); heavy packages without findings: $(@($heavy).Count)"
