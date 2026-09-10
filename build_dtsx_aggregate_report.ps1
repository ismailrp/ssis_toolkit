[CmdletBinding()]
param(
    [string]$ReportPath = '.\results',
    [string]$OutputPath = '.\results',
    [string]$ReportSuffix = 'EVSET-45D-COMPLETE-V8',
    [string]$ExactReportPath = '',
    [string]$MismatchReportPath = '',
    [string]$CandidateReportPath = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
if ([string]::IsNullOrWhiteSpace($ExactReportPath)) { $ExactReportPath = Join-Path $ReportPath ('ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_' + $ReportSuffix + '.csv') }
if ([string]::IsNullOrWhiteSpace($MismatchReportPath)) { $MismatchReportPath = Join-Path $ReportPath ('ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_' + $ReportSuffix + '_MAPPING_MISMATCH.csv') }
if ([string]::IsNullOrWhiteSpace($CandidateReportPath)) { $CandidateReportPath = Join-Path $ReportPath ('ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_' + $ReportSuffix + '_COMMAND_TIME_CANDIDATES.csv') }
$outPath = Join-Path $OutputPath ('DTSX_AGGREGATE_REPORT_' + $ReportSuffix + '.csv')

$categoryMap = [ordered]@{
    anti_sort='anti-sort'; anti_aggregate='anti-aggregate'; anti_fuzzy_lookup='anti-fuzzy-lookup'; anti_fast_load_inactive='anti-fast-load-inactive'; anti_no_tablock='anti-no-tablock'; anti_lookup_partial_no_cache='anti-lookup-partial-no-cache'; anti_select_star='anti-select-star'; anti_oledb_command='anti-oledb-command'; CartesianCrossJoin='cartesian-cross-join'; NonSargableFunctionPredicate='non-sargable-function-predicate'; OnTheFlyFunctionExpression='on-the-fly-function-expression'; NestedViewReference='nested-view-reference'; PivotWindowFunction='pivot-window-function'; UnionAll='union-all'; NoLockAdvisory='nolock-advisory'; MergeJoinComponent='merge-join-component'; ImplicitConversionIndicator='implicit-conversion'; ScriptComponent='script-component'; ADO_NET_or_ODBC_Provider='ado-net-or-odbc-provider'; ExplicitBufferOrThreadSetting='explicit-buffer-or-thread-setting'; TempStoragePathSetting='temp-storage-path'; DestinationCommitSizeSetting='destination-commit-size'; ExecutePackageTask='execute-package-task'; CheckpointSetting='checkpoint-setting'; FullReloadIndicator='full-reload-indicator'
}
function Get-Value([object]$row,[string]$name) { if($row -and $row.PSObject.Properties[$name]){return [string]$row.$name};return '' }
function Get-Categories([object]$row) { $items=New-Object System.Collections.Generic.List[string]; foreach($column in $categoryMap.Keys){$value=Get-Value $row $column; $number=0; if([int]::TryParse($value,[ref]$number) -and $number -gt 0){[void]$items.Add($categoryMap[$column])}}; $aliases=@{'FuzzyLookup'='anti-fuzzy-lookup';'Sort'='anti-sort';'Aggregate'='anti-aggregate';'MergeJoinComponent'='merge-join-component';'ScriptComponent'='script-component'}; $raw=Get-Value $row 'anti_pattern_fields'; foreach($field in ($raw -split ';')){if($aliases.ContainsKey($field) -and !$items.Contains($aliases[$field])){[void]$items.Add($aliases[$field])}};return @($items|Select-Object -Unique) }
function Get-Components([object]$row) { $value=Get-Value $row 'anti_pattern_components';if([string]::IsNullOrWhiteSpace($value)){return @()};return @($value -split ';'|Where-Object{!([string]::IsNullOrWhiteSpace($_))}) }
function Get-PriorityRank([string]$priority) { if($priority -eq 'P1'){return 1};if($priority -eq 'P2'){return 2};if($priority -eq 'P3'){return 3};return 9 }
function Add-NormalizedRow([object]$row,[string]$source,[System.Collections.ArrayList]$target) {
    $location='';$package='';
    if($source -eq 'exact'){$location=('{0}/{1}/{2}'-f $row.folder_name,$row.project_name,$row.package_name);$package=$row.package_name;$duration=[double]$row.avg_package_duration_sec;$priority=[string]$row.priority_level;$module=[string]$row.job_name;$pipeline=[string]$row.step_name}
    else {$parts=([string]$row.command_package).Substring(7).Split('/');$location=$row.command_package.Substring(7);$package=$parts[$parts.Count-1];$duration=[double]$row.job_step_duration_sec;$priority=[string]$row.priority_level;$module=[string]$row.job_name;$pipeline=[string]$row.step_name}
    $item=[pscustomobject]@{Location=$location;Package=$package;Module=$module;Pipeline=$pipeline;Duration=$duration;Priority=$priority;Categories=(Get-Categories $row);Components=(Get-Components $row)}
    [void]$target.Add($item)
}
$normalized=New-Object System.Collections.ArrayList
if(Test-Path -LiteralPath $ExactReportPath){foreach($row in (Import-Csv $ExactReportPath)){Add-NormalizedRow $row 'exact' $normalized}}
if(Test-Path -LiteralPath $MismatchReportPath){foreach($row in (Import-Csv $MismatchReportPath)){Add-NormalizedRow $row 'mismatch' $normalized}}
if(Test-Path -LiteralPath $CandidateReportPath){foreach($row in (Import-Csv $CandidateReportPath)){Add-NormalizedRow $row 'candidate' $normalized}}
$groups=$normalized|Group-Object Location
$result=@();$no=0
foreach($group in ($groups|Sort-Object Name)){$no++;$selected=@($group.Group|Sort-Object Duration -Descending|Select-Object -First 1)[0];$result += [pscustomobject]@{No=('{0:D3}'-f $no);Package=$selected.Package;Module=$selected.Module;Duration=[math]::Round($selected.Duration,2);'Lokasi File'=$selected.Location;'Tipe Pipeline'=$selected.Pipeline;'Kategori Masalah'=($selected.Categories -join ';');findings=($selected.Components -join ';');'Priority Level'=$selected.Priority}}
$result|Export-Csv $outPath -NoTypeInformation -Encoding UTF8
Write-Host "Wrote $outPath ($($result.Count) aggregate rows)"
