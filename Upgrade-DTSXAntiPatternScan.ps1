Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$root = Join-Path (Get-Location) 'assessments\EVSET-001\01_static_packages\extracted'
$outCsv = Join-Path (Get-Location) 'DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv'
$outMd = Join-Path (Get-Location) 'DTSX_ANTIPATTERN_INSPECTION_REPORT.md'

function Count-Match([string]$text, [string]$pattern) {
    return ([regex]::Matches($text, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
}

function Count-ActiveCrossJoin([string]$text) {
    $n = 0
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -notmatch '^\s*--' -and $line -match '\bCROSS\s+JOIN\b') { $n++ }
    }
    return $n
}

$old = @{}
if (Test-Path $outCsv) {
    foreach ($row in (Import-Csv $outCsv)) { $old[$row.PackageFile] = $row }
}

$rows = foreach ($file in (Get-ChildItem $root -Recurse -File -Filter '*.dtsx')) {
    $relative = $file.FullName.Substring($root.Length + 1).Replace('\','/')
    $base = $old[$relative]
    if (!$base) { continue }
    if ($file.Length -gt 1500000) { continue }
    $text = [IO.File]::ReadAllText($file.FullName)
    $row = [ordered]@{ PackageFile=$relative }
    foreach ($name in @('Sort','Aggregate','FuzzyLookup','FastLoadInactive','NoTABLOCK','LookupPartialNoCache','SELECT*','OLEDBCommand')) {
        $row[$name] = if ($base) { [int]$base.$name } else { 0 }
    }
    $row['CartesianCrossJoin'] = Count-ActiveCrossJoin $text
    $row['NonSargableFunctionPredicate'] = Count-Match $text '\b(?:YEAR|MONTH|DAY|UPPER|LOWER|CAST|CONVERT|ISNULL|COALESCE|RTRIM|LTRIM|SUBSTRING|DATEPART|FORMAT)\s*\('
    $row['OnTheFlyFunctionExpression'] = Count-Match $text '\b(?:SUBSTRING|DATEADD|DATEDIFF|CONCAT|CAST|CONVERT|RTRIM|LTRIM|ISNULL|COALESCE|FORMAT)\s*\('
    $row['NestedViewReference'] = Count-Match $text '\b(?:vw_|view_)[A-Za-z0-9_]+'
    $row['PivotWindowFunction'] = Count-Match $text '\b(?:PIVOT|UNPIVOT)\b|\bOVER\s*\('
    $row['UnionAll'] = Count-Match $text '\bUNION\s+ALL\b'
    $row['NoLockAdvisory'] = Count-Match $text '\bNOLOCK\b'
    $row['MergeJoinComponent'] = Count-Match $text 'componentClassID="Microsoft\.MergeJoin"'
    $row['ImplicitConversionIndicator'] = Count-Match $text '(?:Microsoft\.DataConvert|DT_WSTR|DT_STR|DT_NTEXT|DT_TEXT|DT_IMAGE)'
    $row['ScriptComponent'] = Count-Match $text 'componentClassID="Microsoft\.ScriptComponent"'
    $row['ADO.NET_or_ODBC_Provider'] = Count-Match $text '(?:CreationName="ADO\.NET|CreationName="ODBC|ADO\.NET|ODBC)'
    $row['ExplicitBufferOrThreadSetting'] = Count-Match $text '(?:DefaultBufferMaxRows|DefaultBufferSize|AutoAdjustBufferSize|EngineThreads|MaxConcurrentExecutables)'
    $row['TempStoragePathSetting'] = Count-Match $text '(?:BLOBTempStoragePath|BufferTempStoragePath)'
    $row['DestinationCommitSizeSetting'] = Count-Match $text '(?:MaximumInsertCommitSize|CommitSize)'
    $row['ExecutePackageTask'] = Count-Match $text 'Microsoft\.ExecutePackageTask'
    $row['CheckpointSetting'] = Count-Match $text '(?:SaveCheckpoints|CheckpointUsage)'
    $row['FullReloadIndicator'] = Count-Match $text '(?:TRUNCATE\s+TABLE|DELETE\s+FROM|INSERT\s+INTO)'
    [pscustomobject]$row
}

$rows = @($rows | Sort-Object PackageFile)
$rows | Export-Csv $outCsv -NoTypeInformation -Encoding UTF8

$columns = @('Sort','Aggregate','FuzzyLookup','FastLoadInactive','NoTABLOCK','LookupPartialNoCache','SELECT*','OLEDBCommand','CartesianCrossJoin','NonSargableFunctionPredicate','OnTheFlyFunctionExpression','NestedViewReference','PivotWindowFunction','UnionAll','NoLockAdvisory','MergeJoinComponent','ImplicitConversionIndicator','ScriptComponent','ADO.NET_or_ODBC_Provider','ExplicitBufferOrThreadSetting','TempStoragePathSetting','DestinationCommitSizeSetting','ExecutePackageTask','CheckpointSetting','FullReloadIndicator')
$lines = [Collections.Generic.List[string]]::new()
$lines.Add('# DTSX Anti-Pattern Inspection Report — SSIS Tuning Guide Upgrade')
$lines.Add('')
$lines.Add("Scope: $($rows.Count) extracted DTSX files under `assessments/EVSET-001/01_static_packages/extracted`. Existing rules were preserved and guide-based static indicators were added.")
$lines.Add('')
$lines.Add('| Rule | Occurrences | Files | Interpretation |')
$lines.Add('|---|---:|---:|---|')
foreach ($column in $columns) {
    $total = ($rows | Measure-Object -Property $column -Sum).Sum
    $files = @($rows | Where-Object { [int]$_.$column -gt 0 }).Count
    $meaning = switch ($column) {
        'CartesianCrossJoin' { 'Review intent/cardinality; not automatically accidental.' }
        'NonSargableFunctionPredicate' { 'Heuristic SQL candidate; validate execution plan.' }
        'NoLockAdvisory' { 'Advisory only; dirty-read correctness risk.' }
        'MergeJoinComponent' { 'Validate sorted inputs and SortKeyPosition.' }
        'FullReloadIndicator' { 'Heuristic full-reload candidate; validate ETL design.' }
        default { 'Static review candidate; runtime impact not proven.' }
    }
    $lines.Add("| ``$column`` | $total | $files | $meaning |")
}
$lines.Add('')
$lines.Add('## Guide items requiring runtime/server evidence')
$lines.Add('')
$lines.Add('- Index/statistics health, execution plans, filter pushdown effectiveness, tempdb, waits, I/O, CPU/RAM, antivirus exclusions, SSIS logging level, destination indexes/constraints/triggers, and actual buffer spooling cannot be proven from DTSX alone.')
$lines.Add('- Query Store remains unavailable because it is OFF in the captured database state. Use targeted active-request/wait snapshots for selected active jobs.')
$lines.Add('- Static findings are candidates and must be correlated with package/job duration before assigning P0/P1.')
[IO.File]::WriteAllLines($outMd, $lines, [Text.UTF8Encoding]::new($false))
Write-Host "Updated $outCsv and $outMd"
