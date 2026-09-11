[CmdletBinding()]
param(
    [string]$AssessmentPath = '.\assessments\EVSET-45D-COMPLETE',
    [string]$OutputPath = '.\results',
    [string]$GuidePath = '.\results\SSIS_Tuning_Guide.md',
    [string]$ReportSuffix = ''
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$repo=(Get-Location).Path
$assessment=(Resolve-Path -LiteralPath $AssessmentPath).Path
$extractRoot=Join-Path $assessment '01_static_packages\extracted'
$summaryPath=Join-Path $assessment '01_static_packages\package_static_summary.csv'
if(!(Test-Path -LiteralPath $extractRoot)){throw "Extracted DTSX path not found: $extractRoot"}
if(!(Test-Path -LiteralPath $summaryPath)){throw "Static summary not found: $summaryPath"}
if(!(Test-Path -LiteralPath $OutputPath)){New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null}
$suffix=if([string]::IsNullOrWhiteSpace($ReportSuffix)){''}else{'_'+$ReportSuffix}
$outCsv=Join-Path $OutputPath ('DTSX_ANTIPATTERN_PACKAGE_FINDINGS'+$suffix+'.csv')
$outMd=Join-Path $OutputPath ('DTSX_ANTIPATTERN_INSPECTION_REPORT'+$suffix+'.md')

function Count-Match([string]$text,[string]$pattern){if([string]::IsNullOrWhiteSpace($text)){return 0};return ([regex]::Matches($text,$pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count}
function Get-Attr([Xml.XmlNode]$node,[string]$name){if(!$node -or !$node.Attributes){return ''};foreach($a in $node.Attributes){if($a.LocalName -eq $name){return [string]$a.Value}};return ''}
function Get-Prop([Xml.XmlNode]$node,[string]$name){foreach($p in $node.SelectNodes(".//*[local-name()='property']")){if((Get-Attr $p 'name') -eq $name){return [string]$p.InnerText}};return ''}
function Test-True([string]$value){return $value -match '^(?i:true|1|-1)$'}
function Add-Detail([Collections.Generic.List[string]]$items,[string]$rule,[string]$name){if($name){[void]$items.Add(('{0}:{1}' -f $rule,($name-replace';',',')))}}
function Add-SqlDetails([Collections.Generic.List[string]]$items,[string]$name,[string]$sql){
    if([string]::IsNullOrWhiteSpace($name)-or[string]::IsNullOrWhiteSpace($sql)){return}
    $rules=[ordered]@{
        'SELECT*'='\bSELECT\s+(?:TOP\s*\([^)]*\)\s+)?\*\s+FROM\b'
        CartesianCrossJoin='\bCROSS\s+JOIN\b'
        ImplicitCartesianJoin='\bFROM\s+[\[\]\w.]+(?:\s+\w+)?\s*,\s*[\[\]\w.]+'
        NonSargableFunctionPredicate='\b(?:WHERE|ON|AND|OR)\s+(?:\(+\s*)?(?:YEAR|MONTH|DAY|UPPER|LOWER|LEFT|RIGHT|CAST|CONVERT|ISNULL|COALESCE|RTRIM|LTRIM|SUBSTRING|DATEPART|FORMAT)\s*\('
        OnTheFlyFunctionExpression='\b(?:SUBSTRING|DATEADD|DATEDIFF|CONCAT|CAST|CONVERT|RTRIM|LTRIM|ISNULL|COALESCE|FORMAT)\s*\('
        NestedViewReference='\b(?:FROM|JOIN)\s+(?:\[[^]]+\]\.)?\[?(?:vw_|view_)[A-Za-z0-9_]+\]?'
        PivotWindowFunction='\b(?:PIVOT|UNPIVOT)\b|\bOVER\s*\('
        SqlUnionDistinct='\bUNION\b(?!\s+ALL\b)'
        SqlUnionAll='\bUNION\s+ALL\b'
        NoLockAdvisory='\bNOLOCK\b'
        FullReloadIndicator='\bTRUNCATE\s+TABLE\b|\bDELETE\s+FROM\b'
    }
    foreach($rule in $rules.Keys){if((Count-Match $sql $rules[$rule])-gt 0){Add-Detail $items $rule $name}}
}
function Get-SqlText([xml]$xml){
    $parts=New-Object 'System.Collections.Generic.List[string]'
    foreach($p in $xml.SelectNodes("//*[local-name()='property']")){$n=Get-Attr $p 'name';$v=[string]$p.InnerText;if($n-match'(?i)^(SqlCommand|SqlStatementSource|CommandText|OpenRowset)$'-and$v-match'(?i)\b(SELECT|INSERT|UPDATE|DELETE|MERGE|TRUNCATE|EXEC(?:UTE)?)\b'){[void]$parts.Add($v)}}
    foreach($n in $xml.SelectNodes("//*[@*[local-name()='SqlStatementSource']]")){foreach($a in $n.Attributes){if($a.LocalName-match'(?i)SqlStatementSource'-and$a.Value-match'(?i)\b(SELECT|INSERT|UPDATE|DELETE|MERGE|TRUNCATE|EXEC(?:UTE)?)\b'){[void]$parts.Add($a.Value)}}}
    return ($parts-join"`n")
}
function Get-Scan([string]$path,[object]$summary){
    $m=[ordered]@{Sort=0;Aggregate=0;FuzzyLookup=0;FuzzyGrouping=0;LookupComponent=0;LookupPartialNoCache=0;MergeComponent=0;MergeJoinComponent=0;UnionAllComponent=0;ConditionalSplitFilter=0;DataConversionComponent=0;OLEDBCommand=0;ScriptComponent=0;FastLoadInactive=0;NoTABLOCK=0;DestinationCommitSizeSetting=0;'SELECT*'=0;CartesianCrossJoin=0;ImplicitCartesianJoin=0;NonSargableFunctionPredicate=0;OnTheFlyFunctionExpression=0;NestedViewReference=0;PivotWindowFunction=0;SqlUnionDistinct=0;SqlUnionAll=0;NoLockAdvisory=0;FullReloadIndicator=0;ADO_NET_or_ODBC_Provider=0;DelayValidationDisabled=0;ValidateExternalMetadataEnabled=0;ExplicitBufferOrThreadSetting=0;TempStoragePathSetting=0;ExecutePackageTask=0;CheckpointDisabled=0;TransactionEnabled=0;MonolithicPackage=0;ParseError=0}
    $items=New-Object 'System.Collections.Generic.List[string]'
    try{[xml]$xml=[IO.File]::ReadAllText($path)}catch{$m.ParseError=1;return [pscustomobject]@{Metrics=[pscustomobject]$m;Components='';Error=$_.Exception.Message}}
    foreach($c in $xml.SelectNodes("//*[local-name()='component']")){
        $name=Get-Attr $c 'name';$class=Get-Attr $c 'componentClassID';$rule=''
        switch -Regex($class){'(?i)\.Sort$'{$m.Sort++;$rule='Sort';break};'(?i)\.Aggregate$'{$m.Aggregate++;$rule='Aggregate';break};'(?i)FuzzyLookup'{$m.FuzzyLookup++;$rule='FuzzyLookup';break};'(?i)FuzzyGrouping'{$m.FuzzyGrouping++;$rule='FuzzyGrouping';break};'(?i)\.Lookup$'{$m.LookupComponent++;$rule='LookupComponent';$cache=Get-Prop $c 'CacheType';if($cache-match'^(?i:1|2|Partial|NoCache|None)$'){$m.LookupPartialNoCache++;Add-Detail $items 'LookupPartialNoCache' $name};break};'(?i)\.MergeJoin$'{$m.MergeJoinComponent++;$rule='MergeJoinComponent';break};'(?i)\.Merge$'{$m.MergeComponent++;$rule='MergeComponent';break};'(?i)\.UnionAll$'{$m.UnionAllComponent++;$rule='UnionAllComponent';break};'(?i)ConditionalSplit'{$m.ConditionalSplitFilter++;$rule='ConditionalSplitFilter';break};'(?i)DataConvert'{$m.DataConversionComponent++;$rule='DataConversionComponent';break};'(?i)OLEDBCommand'{$m.OLEDBCommand++;$rule='OLEDBCommand';break};'(?i)(Script|ManagedComponentHost)'{$m.ScriptComponent++;$rule='ScriptComponent';break}}
        if($rule){Add-Detail $items $rule $name}
        if($class-match'(?i)OLEDBDestination'){$access=Get-Prop $c 'AccessMode';if($access-ne'3'-and$access-ne'4'){$m.FastLoadInactive++;Add-Detail $items 'FastLoadInactive' $name}else{$options=Get-Prop $c 'FastLoadOptions';if($options-notmatch'(?i)(^|,)\s*TABLOCK\s*(,|$)'){$m.NoTABLOCK++;Add-Detail $items 'NoTABLOCK' $name};$commit=Get-Prop $c 'FastLoadMaxInsertCommitSize';$v=0L;if([int64]::TryParse($commit,[ref]$v)-and$v-gt 0-and$v-lt 100000){$m.DestinationCommitSizeSetting++;Add-Detail $items 'DestinationCommitSizeSetting' $name}}}
        $validate=Get-Prop $c 'ValidateExternalMetadata';if($validate-ne''-and(Test-True $validate)){$m.ValidateExternalMetadataEnabled++}
        $componentSql=New-Object 'System.Collections.Generic.List[string]'
        foreach($p in $c.SelectNodes(".//*[local-name()='property']")){$propertyName=Get-Attr $p 'name';$value=[string]$p.InnerText;if($propertyName-match'(?i)^(SqlCommand|SqlStatementSource|CommandText)$'-and$value-match'(?i)\b(SELECT|INSERT|UPDATE|DELETE|MERGE|TRUNCATE|EXEC(?:UTE)?)\b'){[void]$componentSql.Add($value)}}
        Add-SqlDetails $items $name ($componentSql-join"`n")
    }
    $sql=Get-SqlText $xml
    $m.'SELECT*'=Count-Match $sql '\bSELECT\s+(?:TOP\s*\([^)]*\)\s+)?\*\s+FROM\b';$m.CartesianCrossJoin=Count-Match $sql '\bCROSS\s+JOIN\b';$m.ImplicitCartesianJoin=Count-Match $sql '\bFROM\s+[\[\]\w.]+(?:\s+\w+)?\s*,\s*[\[\]\w.]+';$m.NonSargableFunctionPredicate=Count-Match $sql '\b(?:WHERE|ON|AND|OR)\s+(?:\(+\s*)?(?:YEAR|MONTH|DAY|UPPER|LOWER|LEFT|RIGHT|CAST|CONVERT|ISNULL|COALESCE|RTRIM|LTRIM|SUBSTRING|DATEPART|FORMAT)\s*\(';$m.OnTheFlyFunctionExpression=Count-Match $sql '\b(?:SUBSTRING|DATEADD|DATEDIFF|CONCAT|CAST|CONVERT|RTRIM|LTRIM|ISNULL|COALESCE|FORMAT)\s*\(';$m.NestedViewReference=Count-Match $sql '\b(?:FROM|JOIN)\s+(?:\[[^]]+\]\.)?\[?(?:vw_|view_)[A-Za-z0-9_]+\]?';$m.PivotWindowFunction=Count-Match $sql '\b(?:PIVOT|UNPIVOT)\b|\bOVER\s*\(';$m.SqlUnionDistinct=Count-Match $sql '\bUNION\b(?!\s+ALL\b)';$m.SqlUnionAll=Count-Match $sql '\bUNION\s+ALL\b';$m.NoLockAdvisory=Count-Match $sql '\bNOLOCK\b';$m.FullReloadIndicator=Count-Match $sql '\bTRUNCATE\s+TABLE\b|\bDELETE\s+FROM\b'
    $raw=$xml.OuterXml;$m.ADO_NET_or_ODBC_Provider=Count-Match $raw 'CreationName="[^"]*(?:ADO\.NET|ODBC)|componentClassID="[^"]*(?:ADO\.NET|ODBC|SSISODBC)'
    foreach($n in $xml.SelectNodes("//*[local-name()='Executable']|//*[local-name()='ConnectionManager']")){$delay=Get-Attr $n 'DelayValidation';if($delay-ne''-and!(Test-True $delay)){$m.DelayValidationDisabled++}}
    foreach($p in $xml.SelectNodes("//*[local-name()='Property']|//*[local-name()='property']")){$n=Get-Attr $p 'Name';if(!$n){$n=Get-Attr $p 'name'};if($n-match'^(DefaultBufferMaxRows|DefaultBufferSize|AutoAdjustBufferSize|EngineThreads|MaxConcurrentExecutables)$'){$m.ExplicitBufferOrThreadSetting++};if($n-match'^(BLOBTempStoragePath|BufferTempStoragePath)$'-and![string]::IsNullOrWhiteSpace($p.InnerText)){$m.TempStoragePathSetting++}}
    $m.ExecutePackageTask=Count-Match $raw 'Microsoft\.ExecutePackageTask';if((Count-Match $raw '(?:SaveCheckpoints[^>]*>|Name="SaveCheckpoints"[^>]*>)(?:false|0)')-gt 0-or(Count-Match $raw '(?:CheckpointUsage[^>]*>|Name="CheckpointUsage"[^>]*>)(?:Never|0)')-gt 0){$m.CheckpointDisabled=1};$m.TransactionEnabled=Count-Match $raw '(?:TransactionOption[^>]*>|Name="TransactionOption"[^>]*>)(?:Required|Supported|1|2)'
    $exec=0;$comp=0;if($summary.PSObject.Properties['ExecutableNodeCount']){$exec=[int]$summary.ExecutableNodeCount};if($summary.PSObject.Properties['DataFlowComponentCount']){$comp=[int]$summary.DataFlowComponentCount};if($exec-ge 50-or$comp-ge 100){$m.MonolithicPackage=1}
    return [pscustomobject]@{Metrics=[pscustomobject]$m;Components=(($items|Select-Object -Unique)-join';');Error=''}
}
$columns=@('Sort','Aggregate','FuzzyLookup','FuzzyGrouping','LookupComponent','LookupPartialNoCache','MergeComponent','MergeJoinComponent','UnionAllComponent','ConditionalSplitFilter','DataConversionComponent','OLEDBCommand','ScriptComponent','FastLoadInactive','NoTABLOCK','DestinationCommitSizeSetting','SELECT*','CartesianCrossJoin','ImplicitCartesianJoin','NonSargableFunctionPredicate','OnTheFlyFunctionExpression','NestedViewReference','PivotWindowFunction','SqlUnionDistinct','SqlUnionAll','NoLockAdvisory','FullReloadIndicator','ADO_NET_or_ODBC_Provider','DelayValidationDisabled','ValidateExternalMetadataEnabled','ExplicitBufferOrThreadSetting','TempStoragePathSetting','ExecutePackageTask','CheckpointDisabled','TransactionEnabled','MonolithicPackage','ParseError')
$rows=@();foreach($base in(Import-Csv $summaryPath)){$file=[string]$base.PackageName;if($file-notmatch'(?i)\.dtsx$'){$file+='.dtsx'};$relative=('SSISDB/{0}/{1}/{2}'-f$base.FolderName,$base.ProjectName,$file).Replace('\','/');$path=Join-Path $extractRoot ($relative.Replace('/','\'));if(Test-Path -LiteralPath $path){$scan=Get-Scan $path $base}else{$scan=[pscustomobject]@{Metrics=[pscustomobject]@{ParseError=1};Components='';Error='DTSX file not found'}};$row=[ordered]@{PackageFile=$relative;ParseStatus=if($scan.Metrics.ParseError-eq 0){'OK'}else{'ERROR'};ParseErrorMessage=$scan.Error};foreach($column in $columns){$value=0;if($scan.Metrics.PSObject.Properties[$column]){$value=[int]$scan.Metrics.$column};$row[$column]=$value};$row['anti_pattern_components']=$scan.Components;$rows+=[pscustomobject]$row}
$rows=@($rows|Sort-Object PackageFile);$rows|Export-Csv $outCsv -NoTypeInformation -Encoding UTF8
$special=@{CartesianCrossJoin='Review intent/cardinality; CROSS JOIN can be deliberate.';NoLockAdvisory='Correctness advisory, not a performance recommendation.';LookupComponent='Inventory only; cache mode and runtime volume determine risk.';ExecutePackageTask='Architecture inventory, not an anti-pattern by itself.';ExplicitBufferOrThreadSetting='Configuration inventory; inspect actual values and runtime symptoms.';TempStoragePathSetting='Configuration inventory; does not prove buffer spooling.';CheckpointDisabled='Recovery candidate; useful only for restartable control flows.';TransactionEnabled='Reliability/overhead candidate; preserve transaction semantics.';MonolithicPackage='Complexity candidate: >=50 executables or >=100 data-flow components.'}
$lines=New-Object 'System.Collections.Generic.List[string]';$relativeRoot=($assessment.Substring($repo.Length+1).Replace('\','/')+'/01_static_packages/extracted');$lines.Add('# DTSX Anti-Pattern Inspection Report');$lines.Add('');$lines.Add(('Scope: {0} package rows under `{1}`.'-f$rows.Count,$relativeRoot));$lines.Add(('Guide reference: `{0}`.'-f$GuidePath));$lines.Add('Coverage: all guide rules observable defensibly from DTSX/XML. Runtime, server, database, schedule, and code-semantic rules remain evidence gaps.');$lines.Add('');$lines.Add('| Rule | Occurrences | Files | Interpretation |');$lines.Add('|---|---:|---:|---|');foreach($column in $columns){$total=($rows|Measure-Object -Property $column -Sum).Sum;$count=@($rows|Where-Object{[int]$_.$column-gt 0}).Count;$meaning='Static investigation candidate; runtime impact not proven.';if($special.ContainsKey($column)){$meaning=$special[$column]};$lines.Add(('| `{0}` | {1} | {2} | {3} |'-f$column,$total,$count,$meaning))};$lines.Add('');$lines.Add('## Evidence boundary');$lines.Add('');$lines.Add('- SQL heuristics scan SQL-bearing DTSX properties rather than all XML metadata.');$lines.Add('- Component inventory is not causal proof; correlate with duration, component phase, rows/volume, and comparable tests.');$lines.Add('- Indexes/plans/waits/blocking/I/O, resource pressure, logging, destination triggers, actual spooling, and Script code behavior cannot be proven from DTSX.');$lines.Add('- `ConditionalSplitFilter` is a filter-pushdown candidate; the component can implement valid routing.');$lines.Add('- `DataConversionComponent` is explicit conversion inventory, not proof of an implicit type mismatch.');$lines.Add('- Existing raw evidence and ISPAC/DTSX source files were not modified.');[IO.File]::WriteAllLines($outMd,$lines,(New-Object Text.UTF8Encoding($false)));Write-Host "Wrote $outCsv and $outMd ($($rows.Count) rows; $(@($rows|Where-Object{$_.ParseStatus-ne'OK'}).Count) parse errors)"
