[CmdletBinding()]
param(
    [string]$AggregateReportPath = '.\results\DTSX_AGGREGATE_REPORT_EVSET-45D-COMPLETE-V12.csv',
    [string]$TemplatePath = '.\results\package_findings_detail\SSIS Finding-001-PS_AS_dtsx-Investor Relation v1.0a.docx',
    [string]$OutputPath = '.\results\package_findings_detail',
    [string]$Version = 'v1.0a',
    [int]$MaxDocuments = 0
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-PriorityRank([string]$priority) {
    switch ($priority.ToUpperInvariant()) { 'P0' { 0 } 'P1' { 1 } 'P2' { 2 } 'P3' { 3 } default { 9 } }
}
function Get-SafeName([string]$value) {
    $safe = $value
    foreach ($character in [IO.Path]::GetInvalidFileNameChars()) { $safe = $safe.Replace([string]$character, '_') }
    return (($safe -replace '\s+', ' ').Trim()).TrimEnd('.')
}
function Get-DisplayModule([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return 'Module belum teridentifikasi' }
    return ([Globalization.CultureInfo]::GetCultureInfo('en-US').TextInfo.ToTitleCase(($value -replace '_',' ').ToLowerInvariant()))
}
function Get-Category([object]$row) {
    $category = [string]$row.'Kategori Masalah'
    if (![string]::IsNullOrWhiteSpace($category)) {
        $aliases=@{'sort'='sort';'anti-sort'='sort';'select*'='select-star';'anti-select-star'='select-star';'ado_net_or_odbc_provider'='ado-net-or-odbc-provider';'anti-fuzzy-lookup'='fuzzy-lookup';'anti-aggregate'='aggregate'}
        $seen=@{};$clean=New-Object 'System.Collections.Generic.List[string]'
        foreach($item in($category -split ';')){$key=$item.Trim().ToLowerInvariant();if($aliases.ContainsKey($key)){$key=$aliases[$key]};if($key-and!$seen.ContainsKey($key)){$seen[$key]=$true;[void]$clean.Add($key)}}
        return ($clean -join ', ')
    }
    if ([string]$row.'Lokasi File' -match '(?i)Staging Segregation|STG_FOR_DIM_MILL_COST') { return 'EVIDENCE_MAPPING_GAP' }
    return 'RUNTIME_HOTSPOT_WITHOUT_STATIC_EXPLANATION'
}
function Get-GroupedComponents([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return 'Tidak ada component-level finding pada static scan.' }
    $groups = [ordered]@{}
    foreach ($entry in ($value -split ';')) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $separator = $entry.IndexOf(':')
        $rule = if ($separator -ge 0) { $entry.Substring(0,$separator).Trim() } else { $entry.Trim() }
        $component = if ($separator -ge 0) { $entry.Substring($separator+1).Trim() } else { 'Nama component tidak tersedia' }
        if (!$groups.Contains($rule)) { $groups[$rule] = New-Object 'System.Collections.Generic.List[string]' }
        if (!$groups[$rule].Contains($component)) { [void]$groups[$rule].Add($component) }
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rule in $groups.Keys) { [void]$lines.Add(('- {0} : {1}' -f $rule,($groups[$rule] -join ', '))) }
    return ($lines -join "`v")
}
function Set-DocumentText([object]$document, [string]$oldText, [string]$newText) {
    $range = $document.Content.Duplicate
    $find = $range.Find
    $find.ClearFormatting()
    $find.Text = if ($oldText.Length -gt 120) { $oldText.Substring(0,120) } else { $oldText }
    $find.Forward = $true
    $find.Wrap = 0
    if ($find.Execute()) {
        $paragraphRange = $range.Paragraphs.Item(1).Range
        if ($paragraphRange.End -gt $paragraphRange.Start) { $paragraphRange.End = $paragraphRange.End - 1 }
        $paragraphRange.Text = $newText
    }
}
function Remove-DocumentParagraph([object]$document, [string]$searchText) {
    $range = $document.Content.Duplicate
    $find = $range.Find
    $find.ClearFormatting()
    $find.Text = if ($searchText.Length -gt 120) { $searchText.Substring(0,120) } else { $searchText }
    $find.Forward = $true
    $find.Wrap = 0
    if ($find.Execute()) { $range.Paragraphs.Item(1).Range.Delete() | Out-Null }
}
function Get-EvidenceSolutions([string]$category) {
    $actions = New-Object 'System.Collections.Generic.List[string]'
    $c = $category.ToLowerInvariant()
    if ($c -match 'evidence_mapping_gap') { [void]$actions.Add('Cocokkan SQL Agent command, package path, dan Execution ID sebelum memakai angka durasi.') }
    if ($c -match 'sort') { [void]$actions.Add('Untuk Sort, pastikan urutan memang dibutuhkan. Jika runtime membuktikan Sort mahal, uji pengurutan di source sambil menjaga kontrak sorted input.') }
    if ($c -match 'aggregate') { [void]$actions.Add('Untuk Aggregate, ukur jumlah baris dan component phase; uji agregasi di source hanya jika query plan dan hasil tetap benar.') }
    if ($c -match 'select-star') { [void]$actions.Add('Untuk SELECT *, pilih hanya kolom yang benar-benar dipakai agar row width dan transfer data berkurang.') }
    if ($c -match 'cartesian-cross-join') { [void]$actions.Add('Untuk CROSS JOIN, validasi cardinality dan kebutuhan bisnis; ubah hanya jika perkalian baris tidak disengaja.') }
    if ($c -match 'non-sargable') { [void]$actions.Add('Untuk predicate non-sargable, ambil query dan execution plan lalu uji predicate yang tidak membungkus kolom dengan fungsi.') }
    if ($c -match 'pivot-window') { [void]$actions.Add('Untuk PIVOT/window function, periksa plan, memory grant, dan spill; uji staging/materialisasi hanya bila cost-nya terbukti.') }
    if ($c -match 'conditional-split') { [void]$actions.Add('Untuk Conditional Split, bedakan routing dan filtering; dorong filter ke source hanya untuk baris yang memang tidak diperlukan.') }
    if ($c -match 'merge-join') { [void]$actions.Add('Untuk Merge Join, verifikasi ORDER BY, IsSorted, dan SortKeyPosition pada kedua input sebelum mengubah desain.') }
    if ($c -match 'data-conversion|implicit-conversion') { [void]$actions.Add('Untuk conversion, samakan tipe dan panjang data source-destination setelah metadata mismatch terbukti.') }
    if ($c -match 'script-component') { [void]$actions.Add('Untuk Script Component, review kode per-row dan pindahkan inisialisasi atau koneksi berulang ke PreExecute/PostExecute bila ditemukan.') }
    if ($c -match 'ado-net-or-odbc') { [void]$actions.Add('Untuk provider ADO.NET/ODBC, ukur provider/connection overhead sebelum menguji provider alternatif.') }
    if ($c -match 'full-reload') { [void]$actions.Add('Untuk full reload, bandingkan volume perubahan dengan volume total; uji incremental load hanya jika key dan correctness mendukung.') }
    if ($c -match 'fast-load') { [void]$actions.Add('Untuk destination non-Fast Load, verifikasi access mode dan volume; benchmark Fast Load dalam controlled test.') }
    if ($actions.Count -eq 0) { [void]$actions.Add('Lokalisasi waktu ke executable/component atau source query sebelum memilih perubahan teknis.') }
    return ($actions -join "`v")
}
function Get-PlanningTarget([string]$priority,[double]$durationSeconds,[string]$category) {
    if ($priority -ne 'P1' -or $durationSeconds -le 0 -or $category -match '(?i)evidence_mapping_gap|runtime_hotspot_without_static_explanation') { return '' }
    $minimumPercent = 10
    $targetPercent = 20
    $stretchPercent = 30
    $targetSeconds = $durationSeconds * (1 - ($targetPercent / 100))
    $savingSeconds = $durationSeconds - $targetSeconds
    return ('Target optimasi sementara (planning estimate; bukan jaminan hasil)' + "`v" +
        ('- Baseline observed: {0:N2} detik ({1:N2} menit) per execution.' -f $durationSeconds,($durationSeconds / 60)) + "`v" +
        ('- Target utama client: {0}% reduction; target durasi <= {1:N2} detik ({2:N2} menit).' -f $targetPercent,$targetSeconds,($targetSeconds / 60)) + "`v" +
        ('- Estimasi penghematan pada target: {0:N2} detik ({1:N2} menit) per execution.' -f $savingSeconds,($savingSeconds / 60)) + "`v" +
        ('- Minimum acceptance: {0}% reduction; stretch target: {1}% reduction.' -f $minimumPercent,$stretchPercent) + "`v" +
        '- Confidence: LOW / POSSIBLE sampai component elapsed, row volume, query plan, dan comparable benchmark tersedia.' + "`v" +
        '- Validation: minimal 3 execution comparable dengan parameter, volume data, dan workload window yang setara.' + "`v" +
        '- Success/guardrail: row count, nilai agregat, output downstream, dan success rate tidak memburuk.' + "`v" +
        ('- Rollback/reject: correctness berubah atau median improvement kurang dari {0}%.' -f $minimumPercent))
}
function Set-Cell([object]$table, [int]$row, [int]$column, [string]$text) {
    $table.Cell($row, $column).Range.Text = $text
}

$report = (Resolve-Path -LiteralPath $AggregateReportPath).Path
$template = (Resolve-Path -LiteralPath $TemplatePath).Path
if (!(Test-Path -LiteralPath $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$outputRoot = (Resolve-Path -LiteralPath $OutputPath).Path
$rows = @(Import-Csv $report | Sort-Object `
    @{ Expression = { Get-PriorityRank ([string]$_.'Priority Level') }; Ascending = $true }, `
    @{ Expression = { [double]$_.Duration }; Descending = $true }, `
    @{ Expression = { [string]$_.'Lokasi File' }; Ascending = $true })
if ($MaxDocuments -gt 0) { $rows = @($rows | Select-Object -First $MaxDocuments) }

$word = $null
try {
    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $number = 0
    foreach ($row in $rows) {
        $number++
        $sequence = '{0:D3}' -f $number
        $package = [string]$row.Package
        $module = Get-DisplayModule ([string]$row.Module)
        $category = Get-Category $row
        $evidenceSolutions = Get-EvidenceSolutions $category
        $priority = [string]$row.'Priority Level'
        $durationSeconds = [double]$row.Duration
        $planningTarget = Get-PlanningTarget $priority $durationSeconds $category
        if (![string]::IsNullOrWhiteSpace($planningTarget)) { $evidenceSolutions += ("`v`v" + $planningTarget) }
        $durationText = if ($durationSeconds -ge 60) { '{0:N2} menit ({1:N2} detik)' -f ($durationSeconds / 60), $durationSeconds } else { '{0:N2} detik' -f $durationSeconds }
        $location = ([string]$row.'Lokasi File').Replace('/', '\')
        $pipeline = [string]$row.'Tipe Pipeline'
        if ([string]::IsNullOrWhiteSpace($pipeline)) { $pipeline = 'Belum teridentifikasi' }
        $components = Get-GroupedComponents ([string]$row.findings)

        $packageFilePart = Get-SafeName ($package.Replace('.', '_'))
        $moduleFilePart = Get-SafeName $module
        $fileName = 'SSIS Finding-{0}-{1}-{2} {3}.docx' -f $sequence,$packageFilePart,$moduleFilePart,$Version
        $destination = Join-Path $outputRoot $fileName
        Copy-Item -LiteralPath $template -Destination $destination -Force
        $document = $word.Documents.Open($destination, $false, $false)
        try {
            while ($document.InlineShapes.Count -gt 0) { $document.InlineShapes.Item(1).Delete() }
            while ($document.Shapes.Count -gt 0) { $document.Shapes.Item(1).Delete() }

            Set-DocumentText $document '001-PS_AS.dtsx' ($sequence + '-' + $package)
            Set-DocumentText $document 'Investor Relations' $module
            Remove-DocumentParagraph $document 'Query pada sumber BUDGET_BGFIP_SUM dan PRODUKSI_SPB_SUM menggunakan rangkaian CTE raksasa:'
            Set-DocumentText $document 'Perkalian Kartesian Jutaan Baris di Memory:' ('Evidence classification: ' + $category + '. Static indicator adalah kandidat investigasi dan belum membuktikan root cause atau dampak runtime.')
            Set-DocumentText $document 'Ketiadaan Materialisasi TempDB: Karena ditulis sebagai CTE (bukan tabel fisik/temp table), SQL Server tidak membuat indeks perantara. Saat melakukan LEFT JOIN dan WINDOW FUNCTION OVER (...) , SQL Server kehabisan RAM dan melakukan spill-totempdb secara masif, membakar utilitas CPU 100%.' ('Bottleneck Location' + "`v" + $components)
            Remove-DocumentParagraph $document 'dsds'
            Remove-DocumentParagraph $document 'Eliminasi Cartesian CROSS JOIN CTE:'
            Remove-DocumentParagraph $document 'Ganti CTE perkalian kartesian dengan tabel referensi master kombinasi yang sudah dimaterialisasi atau lakukan query langsung berbasis transaksi aktual yang ada (Sparse Join alih-alih Dense Matrix Generation).'
            Set-DocumentText $document 'Materialisasi Menggunakan #Temp Table Berindeks via Stored Procedure:' 'Rekomendasi, validasi, dan target berdasarkan evidence classification'
            Set-DocumentText $document 'Pisahkan proses UNPIVOT ke dalam #Temp_Budget dengan CLUSTERED INDEX (TAHUN, UNIT_CODE, DIV_CODE, BULAN) .' $evidenceSolutions
            Remove-DocumentParagraph $document 'Pra-Kalkulasi SDBI (Cumulative Sum):'
            Remove-DocumentParagraph $document 'Pindahkan kalkulasi kumulatif bulanan (Year-to-Date / SDBI) ke batch proses SQL staging terpisah sebelum ditarik oleh SSIS.'

            $table = $document.Tables.Item(1)
            Set-Cell $table 1 2 $sequence
            Set-Cell $table 2 2 $package
            Set-Cell $table 3 2 $module
            Set-Cell $table 4 2 $durationText
            Set-Cell $table 5 2 $location
            Set-Cell $table 6 2 $pipeline
            Set-Cell $table 7 2 $category
            Set-Cell $table 8 2 ($priority + ' - action type: ' + $(if ($category -eq 'EVIDENCE_MAPPING_GAP') { 'VALIDATE FIRST' } else { 'INVESTIGATE' }))
            $document.Save()
        }
        finally {
            $document.Close($false)
            [Runtime.InteropServices.Marshal]::ReleaseComObject($document) | Out-Null
        }
    }
}
finally {
    if ($word) { $word.Quit(); [Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}
Write-Host ('Wrote {0} DOCX files to {1}' -f $rows.Count,$outputRoot)
