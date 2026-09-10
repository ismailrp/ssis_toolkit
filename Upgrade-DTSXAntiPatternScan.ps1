[CmdletBinding()]
param(
    [string]$AssessmentPath = '.\assessments\EVSET-45D-COMPLETE',
    [string]$OutputPath = '.\results',
    [string]$GuidePath = '.\results\SSIS_Tuning_Guide.md',
    [string]$ReportSuffix = ''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$repo = (Get-Location).Path
$assessment = (Resolve-Path -LiteralPath $AssessmentPath).Path
$extractRoot = Join-Path $assessment '01_static_packages\extracted'
if (!(Test-Path -LiteralPath $extractRoot)) { throw "Extracted DTSX path not found: $extractRoot" }
if (!(Test-Path -LiteralPath $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$suffix = if ([string]::IsNullOrWhiteSpace($ReportSuffix)) { '' } else { '_' + $ReportSuffix }
$outCsv = Join-Path $OutputPath ('DTSX_ANTIPATTERN_PACKAGE_FINDINGS' + $suffix + '.csv')
$outMd = Join-Path $OutputPath ('DTSX_ANTIPATTERN_INSPECTION_REPORT' + $suffix + '.md')
$summaryPath = Join-Path $assessment '01_static_packages\package_static_summary.csv'
function Count-Match([string]$text, [string]$pattern) { return ([regex]::Matches($text, $pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count }
function Count-Token([string]$text, [string]$token) {
    $source = $text; $needle = $token; $n = 0; $at = 0
    while (($at = $source.IndexOf($needle, $at, [StringComparison]::Ordinal)) -ge 0) { $n++; $at += $needle.Length }
    return $n
}
function Count-AnyToken([string]$text, [string[]]$tokens) { $n=0; foreach($token in $tokens){$n += Count-Token $text $token}; return $n }
function Count-ActiveCrossJoin([string]$text) { $n=0; foreach($line in ($text -split "`r?`n")){if($line -notmatch '^\s*--' -and $line -match '\bCROSS\s+JOIN\b'){$n++}}; return $n }
function Count-CommitRisk([string]$text) { $n=0; foreach($m in [regex]::Matches($text,'name="FastLoadMaxInsertCommitSize">\s*(\d+)\s*</property>',[Text.RegularExpressions.RegexOptions]::IgnoreCase)){ $v=[int64]$m.Groups[1].Value; if($v -gt 0 -and $v -lt 100000 -and $v -ne 2147483647){$n++}}; return $n }
function Get-Value([object]$row,[string]$name) { if($row -and $row.PSObject.Properties[$name]){if([string]$row.$name -eq 'True'){return 1};if([string]$row.$name -eq 'False'){return 0};return [int]$row.$name};return 0 }
function Get-ComponentFindings([string]$path,[object]$summary) {
    $items=New-Object System.Collections.Generic.List[string]
    if(!(Test-Path -LiteralPath $path)){return ''}
    try { [xml]$xml=Get-Content -Raw -LiteralPath $path } catch { return '' }
    foreach($component in $xml.SelectNodes("//*[local-name()='component']")) {
        $name=[string]$component.GetAttribute('name'); $class=[string]$component.GetAttribute('componentClassID')
        if([string]::IsNullOrWhiteSpace($name)){continue}
        $rule=''
        if((Get-Value $summary 'HasSortIndicator') -eq 1 -and $class -match '(?i)Sort'){$rule='Sort'}
        elseif((Get-Value $summary 'HasAggregateIndicator') -eq 1 -and $class -match '(?i)Aggregate'){$rule='Aggregate'}
        elseif((Get-Value $summary 'HasMergeIndicator') -eq 1 -and $class -match '(?i)MergeJoin'){$rule='MergeJoinComponent'}
        elseif((Get-Value $summary 'HasLookupIndicator') -eq 1 -and $class -match '(?i)Lookup'){$rule='FuzzyLookup'}
        elseif((Get-Value $summary 'HasScriptIndicator') -eq 1 -and $class -match '(?i)Script'){$rule='ScriptComponent'}
        if($rule){[void]$items.Add(('{0}:{1}' -f $rule,$name))}
    }
    foreach($property in $xml.SelectNodes("//*[local-name()='property']")) {
        if(([string]$property.InnerText) -notmatch '(?is)\bselect\s+\*'){continue}
        $parent=$property.ParentNode; $componentName=''
        while($parent -and !$componentName){if($parent.LocalName -eq 'component'){$componentName=[string]$parent.GetAttribute('name')};$parent=$parent.ParentNode}
        if($componentName){[void]$items.Add(('SELECT*:{0}' -f $componentName))}
    }
    return (($items | Select-Object -Unique) -join ';')
}
function Get-SelectStarCount([string]$path) {
    if(!(Test-Path -LiteralPath $path)){return 0}
    try { $text=[IO.File]::ReadAllText($path); return ([regex]::Matches($text,'(?is)\bselect\s+\*')).Count } catch { return 0 }
}
function Get-TextPatternMetrics([string]$text) {
    $m=[ordered]@{}
    $m.FastLoadInactive=Count-Match $text '(?is)componentClassID="[^"]*OLEDBDestination[^"]*".*?FastLoadOptions.*?(?!TABLOCK)'
    $m.NoTABLOCK=Count-Match $text '(?is)FastLoadOptions">(?![^<]*TABLOCK)[^<]*</property>'
    $m.LookupPartialNoCache=Count-Match $text '(?is)(?:CacheType|CacheMode)[^>]*>[^<]*(?:Partial|NoCache)'
    $m.OLEDBCommand=Count-Match $text '(?i)(?:componentClassID="[^"]*OLEDBCommand|DTS:ExecutableType="[^"]*ExecuteSQLTask)'
    $m.CartesianCrossJoin=Count-ActiveCrossJoin $text
    $m.NonSargableFunctionPredicate=Count-Match $text '\b(?:YEAR|MONTH|DAY|UPPER|LOWER|CAST|CONVERT|ISNULL|COALESCE|RTRIM|LTRIM|SUBSTRING|DATEPART|FORMAT)\s*\('
    $m.OnTheFlyFunctionExpression=Count-Match $text '\b(?:SUBSTRING|DATEADD|DATEDIFF|CONCAT|CAST|CONVERT|RTRIM|LTRIM|ISNULL|COALESCE|FORMAT)\s*\('
    $m.NestedViewReference=Count-Match $text '\b(?:vw_|view_)[A-Za-z0-9_]+'; $m.PivotWindowFunction=Count-Match $text '\b(?:PIVOT|UNPIVOT)\b|\bOVER\s*\('; $m.UnionAll=Count-Match $text '\bUNION\s+ALL\b'; $m.NoLockAdvisory=Count-Match $text '\bNOLOCK\b'
    $m.ImplicitConversionIndicator=Count-Match $text '(?:Microsoft\.DataConvert|DT_WSTR|DT_STR|DT_NTEXT|DT_TEXT|DT_IMAGE)'; $m.ADO_NET_or_ODBC_Provider=Count-Match $text '(?:CreationName="ADO\.NET|CreationName="ODBC|ADO\.NET|ODBC)'; $m.ExplicitBufferOrThreadSetting=Count-Match $text '(?:DefaultBufferMaxRows|DefaultBufferSize|AutoAdjustBufferSize|EngineThreads|MaxConcurrentExecutables)'; $m.TempStoragePathSetting=Count-Match $text '(?:BLOBTempStoragePath|BufferTempStoragePath)'; $m.DestinationCommitSizeSetting=Count-CommitRisk $text; $m.ExecutePackageTask=Count-Match $text 'Microsoft\.ExecutePackageTask'; $m.CheckpointSetting=Count-Match $text '(?:SaveCheckpoints|CheckpointUsage)'; $m.FullReloadIndicator=Count-Match $text '(?:TRUNCATE\s+TABLE|DELETE\s+FROM|INSERT\s+INTO)'
    return [pscustomobject]$m
}
$summaryMap=@{}
if(Test-Path -LiteralPath $summaryPath){foreach($s in (Import-Csv $summaryPath)){$key=('SSISDB/{0}/{1}/{2}' -f $s.FolderName,$s.ProjectName,$s.PackageName).Replace('\','/');$summaryMap[$key]=$s}}
$rows=@()
if(!(Test-Path -LiteralPath $summaryPath)){throw "Static summary not found: $summaryPath"}
foreach($base in (Import-Csv $summaryPath)){
    $packageFile = [string]$base.PackageName
    if($packageFile -notmatch '(?i)\.dtsx$'){$packageFile += '.dtsx'}
    $relative=('SSISDB/{0}/{1}/{2}' -f $base.FolderName,$base.ProjectName,$packageFile).Replace('\','/')
    $dtsxPath=Join-Path $extractRoot ($relative.Replace('/','\')); $rawText=''; try{$rawText=[IO.File]::ReadAllText($dtsxPath)}catch{}; $components=Get-ComponentFindings $dtsxPath $base; $metrics=Get-TextPatternMetrics $rawText
    $row=[ordered]@{PackageFile=$relative;Sort=(Get-Value $base 'HasSortIndicator');Aggregate=(Get-Value $base 'HasAggregateIndicator');FuzzyLookup=(Get-Value $base 'HasLookupIndicator');FastLoadInactive=$metrics.FastLoadInactive;NoTABLOCK=$metrics.NoTABLOCK;LookupPartialNoCache=$metrics.LookupPartialNoCache;'SELECT*'=(Count-Match $rawText '(?is)\bselect\s+\*');OLEDBCommand=$metrics.OLEDBCommand;CartesianCrossJoin=$metrics.CartesianCrossJoin;NonSargableFunctionPredicate=$metrics.NonSargableFunctionPredicate;OnTheFlyFunctionExpression=$metrics.OnTheFlyFunctionExpression;NestedViewReference=$metrics.NestedViewReference;PivotWindowFunction=$metrics.PivotWindowFunction;UnionAll=$metrics.UnionAll;NoLockAdvisory=$metrics.NoLockAdvisory;MergeJoinComponent=(Get-Value $base 'HasMergeIndicator');ImplicitConversionIndicator=$metrics.ImplicitConversionIndicator;ScriptComponent=(Get-Value $base 'HasScriptIndicator');ADO_NET_or_ODBC_Provider=$metrics.ADO_NET_or_ODBC_Provider;ExplicitBufferOrThreadSetting=$metrics.ExplicitBufferOrThreadSetting;TempStoragePathSetting=$metrics.TempStoragePathSetting;DestinationCommitSizeSetting=$metrics.DestinationCommitSizeSetting;ExecutePackageTask=$metrics.ExecutePackageTask;CheckpointSetting=$metrics.CheckpointSetting;FullReloadIndicator=$metrics.FullReloadIndicator;anti_pattern_components=$components}
    $rows += [pscustomobject]$row
}
$rows=@($rows|Sort-Object PackageFile);$rows|Export-Csv $outCsv -NoTypeInformation -Encoding UTF8
$columns=@('Sort','Aggregate','FuzzyLookup','FastLoadInactive','NoTABLOCK','LookupPartialNoCache','SELECT*','OLEDBCommand','CartesianCrossJoin','NonSargableFunctionPredicate','OnTheFlyFunctionExpression','NestedViewReference','PivotWindowFunction','UnionAll','NoLockAdvisory','MergeJoinComponent','ImplicitConversionIndicator','ScriptComponent','ADO_NET_or_ODBC_Provider','ExplicitBufferOrThreadSetting','TempStoragePathSetting','DestinationCommitSizeSetting','ExecutePackageTask','CheckpointSetting','FullReloadIndicator')
$lines=New-Object 'System.Collections.Generic.List[string]';$lines.Add('# DTSX Anti-Pattern Inspection Report');$lines.Add('');$lines.Add(('Scope: {0} extracted DTSX files under `{1}`.' -f $rows.Count,($assessment.Substring($repo.Length+1).Replace('\','/')+'/01_static_packages/extracted')));$lines.Add(('Guide reference: `{0}`.' -f $GuidePath));$lines.Add('');$lines.Add('| Rule | Occurrences | Files | Interpretation |');$lines.Add('|---|---:|---:|---|')
foreach($column in $columns){$total=($rows|Measure-Object -Property $column -Sum).Sum;$count=@($rows|Where-Object{[int]$_.$column -gt 0}).Count;$meaning='Static review candidate; runtime impact not proven.';if($column -eq 'CartesianCrossJoin'){$meaning='Review intent/cardinality; not automatically accidental.'};if($column -eq 'NoLockAdvisory'){$meaning='Advisory only; dirty-read correctness risk.'};$lines.Add(('| ``{0}`` | {1} | {2} | {3} |' -f $column,$total,$count,$meaning))}
$lines.Add('');$lines.Add('## Evidence boundary');$lines.Add('');$lines.Add('- Static indicators are candidates, not proof of a runtime bottleneck. Correlate with runtime duration, executable timing, status, and comparable executions.');$lines.Add('- Query plans, waits, blocking, I/O, CPU/RAM, tempdb, destination indexes, and actual buffer spooling require runtime/server evidence.');$lines.Add('- Findings are generated standalone from the selected assessment; no previous findings baseline is required.');[IO.File]::WriteAllLines($outMd,$lines,(New-Object Text.UTF8Encoding($false)));Write-Host "Wrote $outCsv and $outMd ($($rows.Count) rows)"
