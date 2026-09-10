# How to Run All SSIS Evidence Collectors

Dokumen ini menjelaskan alur dari kondisi awal sampai evidence siap dianalisis.
Collector bersifat read-only: tidak menjalankan package, tidak mengubah SSISDB,
SQL Agent, Query Store, atau database source/destination.

## 1. Prasyarat

- Jalankan dari Windows PowerShell 4.0 atau lebih baru.
- Gunakan account yang dapat membaca SSISDB dan metadata SQL Agent di `msdb`.
- Pastikan koneksi ke SQL Server pada `ServerInstance` berhasil.
- Siapkan folder input ISPAC jika static evidence diperlukan.
- Pastikan ruang disk cukup, terutama jika window runtime luas dan messages aktif.

Jalankan semua command dari root repository:

```powershell
Set-Location C:\Projects\sql\ssis_toolkit
```

Jangan memasukkan password, connection string, token, atau path sensitif ke git,
report, log, atau prompt. Jika memakai SQL authentication, isi credential hanya
di konfigurasi lokal yang tidak di-commit.

## 2. Siapkan `config.ps1`

Atur nilai berikut secara eksplisit:

```powershell
ServerInstance = "SQLSERVER\INSTANCE"
IspacRoot = "D:\evidence\ispac"
OutputRoot = ".\assessments"

CollectStatic = $true
CollectRuntime = $true
CollectMessages = $true
CollectQueryStore = $false
CollectAdditionalEvidence = $false

FolderNames = @()
ProjectNames = @()
PackageNames = @()
```

Array filter kosong berarti seluruh folder/project/package. Static collection
membutuhkan `IspacRoot`; runtime-only tidak membutuhkan ISPAC.

## 3. Jalankan full core evidence

Untuk assessment normal:

```powershell
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 `
  -AssessmentId EVSET-YYYYMMDD-CORE
```

Untuk time window lebih luas dan tidak dibatasi jumlah execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 `
  -StartTime "2026-01-01 00:00:00" `
  -EndTime "2026-04-01 00:00:00" `
  -MaxExecutions 0 `
  -AssessmentId EVSET-Q1-CORE
```

Alternatif window relatif:

```powershell
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 `
  -LookbackDays 90 `
  -MaxExecutions 0 `
  -AssessmentId EVSET-90D-CORE
```

`MaxExecutions 0` berarti unlimited. Jika tidak diberikan, nilai dari
`config.ps1` digunakan. `EndTime` bersifat eksklusif.

## 4. Jalankan optional additional evidence

Mode ini mengumpulkan evidence yang tidak diulang oleh core collector:

- SQL Agent job steps, commands yang sudah di-redact, retry settings, history,
  schedules, dan candidate job-package mapping;
- Query Store availability/state seluruh database;
- wrapper/procedure references pada database yang dikonfigurasi.

Aktifkan untuk assessment baru:

```powershell
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 `
  -LookbackDays 90 `
  -MaxExecutions 0 `
  -AdditionalEvidence `
  -AssessmentId EVSET-90D-ADDITIONAL
```

Database untuk query per database tidak wajib diisi manual. Dengan konfigurasi
default, collector menemukan otomatis seluruh database user yang online
(`database_id > 4`). Untuk Query Store, hanya database yang `is_query_store_on = 1`
yang diproses. Untuk wrapper references, seluruh database user online diproses.

Jika ingin membatasi scope, isi daftar database di `config.ps1`; daftar manual
akan menjadi override:

```powershell
AdditionalEvidenceDatabases = @(
    "SourceDB",
    "DestinationDB"
)
```

Jika daftar tersebut kosong, auto-discovery digunakan. Query Store ranking tidak
mengulang output core dan tetap dikontrol oleh `CollectQueryStore` serta
`QueryStoreDatabases`; jangan mengaktifkannya hanya karena best practice tanpa
scope database dan kebutuhan evidence yang jelas.

Jangan menggabungkan `-StaticOnly` dengan `-AdditionalEvidence`. Static-only
memang akan melewati additional evidence karena tidak mengambil runtime.

## 5. Pilihan mode lain

Static-only:

```powershell
powershell -ExecutionPolicy Bypass -File .\New-SSISAssessment.ps1 `
  -StaticOnly -AssessmentId EVSET-STATIC-YYYYMMDD
```

Runtime-only diatur melalui `config.ps1`:

```powershell
CollectStatic = $false
CollectRuntime = $true
```

Shortcut lama berikut tetap tersedia, tetapi hanya meneruskan ke entry point
tunggal:

```powershell
powershell -ExecutionPolicy Bypass -File .\Collect-StaticOnly.ps1 `
  -AssessmentId EVSET-STATIC-YYYYMMDD
```

## 6. Struktur output

Setiap run harus memakai `AssessmentId` baru. Output utama berada di:

```text
assessments\<AssessmentId>\
├─ 00_manifest\
├─ 01_static_packages\
├─ 02_ssisdb_inventory\
├─ 03_runtime\
├─ 04_messages\
├─ 05_sqlserver_optional\
├─ 06_additional_evidence\       # bila mode optional aktif
└─ collector.log
```

File manifest paling penting:

- `00_manifest\collector_environment.csv`: server, window, cap, mode, dan
  konfigurasi efektif;
- `00_manifest\evidence_manifest.csv`: daftar file dan ukuran output;
- `00_manifest\server_identity.csv`: identitas server yang menjawab query;
- `03_runtime\executions.csv`: population runtime utama;
- `03_runtime\executable_statistics.csv`: timing executable;
- `03_runtime\execution_component_phases.csv`: component phase bila tersedia;
- `03_runtime\execution_data_statistics.csv`: rows/path statistics bila tersedia;
- `06_additional_evidence\sql_agent\04_candidate_job_package_mapping.csv`:
  mapping kandidat, bukan bukti final tanpa review command/path.

## 7. Validasi setelah collection

Jalankan pemeriksaan dasar:

```powershell
$root = Resolve-Path .\assessments\EVSET-90D-ADDITIONAL
Get-Content (Join-Path $root "collector.log") -Tail 40
Import-Csv (Join-Path $root "00_manifest\collector_environment.csv")
Import-Csv (Join-Path $root "00_manifest\evidence_manifest.csv") |
  Sort-Object RelativePath |
  Format-Table RelativePath,SizeBytes -AutoSize
Get-ChildItem $root -Recurse |
  Where-Object { -not $_.PSIsContainer -and $_.Name -like "*.error.txt" } |
  Select-Object FullName
```

Periksa hal berikut sebelum analisis:

1. `collector.log` menunjukkan assessment selesai.
2. `collector_environment.csv` sesuai server, window, filter, dan mode yang
   direncanakan.
3. File error tidak diabaikan; query yang gagal dicatat sebagai evidence gap.
4. `executions.csv` direkonsiliasi dengan `package_runtime_summary.csv`.
5. `executable_statistics.csv` tidak dijumlahkan naif jika executable nested
   atau overlap.
6. File component/data yang kosong dilaporkan sebagai evidence tidak tersedia,
   bukan sebagai zero rows atau zero bottleneck.
7. Jumlah execution dan observation window dicatat sebagai raw population,
   bukan digabung dengan summary population tanpa rekonsiliasi.
8. Candidate job-package mapping diberi label candidate sampai command, waktu,
   dan package path diverifikasi.

## 8. Siapkan paket untuk analisis

Analisis dimulai setelah assessment ID, server, observation window, filter,
parameter/environment, dan status collection dicatat. Gunakan raw evidence
sebagai source of truth, kemudian gunakan summary/report untuk konteks.

Minimal paket runtime:

```text
00_manifest\*
03_runtime\executions.csv
03_runtime\executable_statistics.csv
03_runtime\execution_component_phases.csv
03_runtime\execution_data_statistics.csv
04_messages\event_messages.csv
04_messages\operation_messages.csv
```

Tambahkan bila mode optional aktif:

```text
06_additional_evidence\sql_agent\*
06_additional_evidence\05_query_store_database_state.csv
06_additional_evidence\wrapper_references\*
```

Jangan menyimpulkan root cause, bottleneck component, rows/sec, query/index
issue, blocking, wait, atau database cause jika evidence terkait belum ada.

## 9. Buat report active job / anti-pattern

Setelah collection selesai dan file input tervalidasi, buat report menggunakan
`build_active_job_antipattern_report.ps1`. Script ini membaca assessment secara
langsung dan menggunakan exact `Execution ID` yang ditemukan di SQL Agent
history message.

Jalankan dari root repository:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_active_job_antipattern_report.ps1 `
  -AssessmentPath .\assessments\EVSET-90D-COMPLETE `
  -OutputPath .\results `
  -ReportSuffix EVSET-90D-COMPLETE
```

Untuk assessment ini:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_active_job_antipattern_report.ps1 `
  -AssessmentPath .\assessments\EVSET-45D-COMPLETE `
  -OutputPath .\results `
  -ReportSuffix EVSET-45D-COMPLETE
```

Input assessment yang digunakan:

```text
06_additional_evidence\sql_agent\02_sql_agent_job_history.csv
06_additional_evidence\sql_agent\01_sql_agent_job_steps.csv
03_runtime\executions.csv
01_static_packages\package_static_summary.csv
```

Script juga tetap mendukung mode legacy tanpa `-AssessmentPath`; mode tersebut
membaca file manual dari `queries\` dan `DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv`.

Output report:

```text
results\ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_<AssessmentId>.md
results\ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_<AssessmentId>.csv
```

Validasi output:

```powershell
$reportCsv = '.\results\ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_EVSET-45D-COMPLETE.csv'
$rows = @(Import-Csv $reportCsv)
"Rows=$($rows.Count)"
"Columns=$($rows[0].PSObject.Properties.Count)"
$rows | Select-Object -First 10 job_name,step_name,package_name,
  execution_count,priority_level,priority_basis | Format-Table -AutoSize
```

Report hanya menyertakan SQL Agent job aktif dan mapping dengan exact `Execution
ID`. Mapping yang hanya berdasarkan time overlap tidak dimasukkan. Jika static
source hanya `package_static_summary.csv`, kolom anti-pattern yang tidak tersedia
akan kosong. `Sort`, `Lookup`, `Merge`, `Aggregate`, dan `Script` tetap merupakan
static indicator/investigation clue, bukan bukti bottleneck runtime.

## 10. Membuat report anti-pattern dan runtime-heavy

Setelah assessment memiliki static extraction dan runtime summary, jalankan scanner
standalone berikut. `-ReportSuffix` menjaga output assessment baru tetap terpisah dari
file report lama.

```powershell
powershell -ExecutionPolicy Bypass -File .\Upgrade-DTSXAntiPatternScan.ps1 `
  -AssessmentPath .\assessments\EVSET-45D-COMPLETE `
  -OutputPath .\results `
  -GuidePath .\results\SSIS_Tuning_Guide.md `
  -ReportSuffix EVSET-45D-COMPLETE

powershell -ExecutionPolicy Bypass -File .\Repair-DestinationCommitFindings.ps1 `
  -AssessmentPath .\assessments\EVSET-45D-COMPLETE `
  -OutputPath .\results `
  -ReportSuffix EVSET-45D-COMPLETE
```

Output:

```text
results\DTSX_ANTIPATTERN_PACKAGE_FINDINGS_EVSET-45D-COMPLETE.csv
results\DTSX_ANTIPATTERN_INSPECTION_REPORT_EVSET-45D-COMPLETE.md
results\RUNTIME_HEAVY_WITHOUT_ANTIPATTERN_EVSET-45D-COMPLETE.csv
```

Scanner menggunakan `01_static_packages\package_static_summary.csv` assessment
sebagai inventory/indikator komponen dan melakukan scan SQL text DTSX untuk
indikator `SELECT *`, sehingga tidak membutuhkan baseline
`DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv` lama dan tidak mengubah file findings lama.
`RUNTIME_HEAVY_WITHOUT_ANTIPATTERN.csv` berisi package dengan average runtime minimal
600 detik tanpa indikator statis pada output assessment tersebut. Hasil ini adalah
daftar investigasi, bukan bukti bahwa anti-pattern menyebabkan durasi runtime.

## 11. Korelasi opsional untuk mapping mismatch

Jika report memiliki `*_MAPPING_MISMATCH.csv`, jalankan mode kandidat berikut:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_active_job_antipattern_report.ps1 `
  -AssessmentPath .\assessments\EVSET-45D-COMPLETE `
  -OutputPath .\results `
  -ReportSuffix EVSET-45D-COMPLETE-V7 `
  -IncludeCommandTimeCandidates `
  -CandidateToleranceSeconds 60
```

Mode ini mencocokkan package pada SQL Agent command dengan folder/project/package dan
overlap waktu pada `executions.csv`. Hasilnya ditulis ke
`ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_<suffix>_COMMAND_TIME_CANDIDATES.csv` dengan
confidence `COMMAND_TIME_CANDIDATE` jika hanya ada satu kandidat, atau
`AMBIGUOUS_TIME_OVERLAP` jika lebih dari satu. Kandidat tidak digabung ke report exact
dan tidak boleh dipakai sebagai bukti `Execution ID` tanpa verifikasi tambahan. Kedua
file tambahan juga memuat `anti_pattern_count` dan `anti_pattern_fields` berdasarkan
static findings package pada assessment, sehingga status anti-pattern dapat diperiksa
langsung untuk setiap mismatch/candidate. Output juga memuat `job_step_start_time`,
`job_step_end_time`, `job_step_duration_sec`, `priority_level`,
`priority_confidence=PROVISIONAL_JOB_STEP`, dan `priority_basis`. P level ini berasal
dari durasi SQL Agent, bukan durasi SSISDB exact, sehingga harus diperlakukan sebagai
prioritas sementara.
Report findings dan active-job juga memuat `anti_pattern_components`; nama component
ditulis dalam satu kolom dan dipisahkan dengan semicolon (`;`).

## 12. Membuat aggregate report per DTSX

Setelah report V8/V7 tersedia, buat report gabungan berikut:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_dtsx_aggregate_report.ps1 `
  -ReportPath .\results `
  -OutputPath .\results `
  -ReportSuffix EVSET-45D-COMPLETE-V8
```

Output:

```text
results\DTSX_AGGREGATE_REPORT_EVSET-45D-COMPLETE-V8.csv
```

Report menggabungkan exact mapping, mapping mismatch, dan command-time candidates.
Agregasi dilakukan unik per `Lokasi File` DTSX. Jika satu DTSX muncul pada beberapa
job/step, baris dengan `Duration` tertinggi dipilih beserta module dan tipe pipeline-nya.
`Duration` adalah rata-rata durasi yang tersedia dari sumber masing-masing;
untuk mismatch/candidate digunakan durasi SQL Agent step dan priority bersifat provisional.
Kategori pada aggregate menormalkan nama field exact dan nama field supplemental,
misalnya `FuzzyLookup` menjadi `anti-fuzzy-lookup`.

Jika file output dengan nama yang sama sedang terbuka atau terkunci, gunakan
suffix baru, misalnya `EVSET-45D-COMPLETE-V2`. Jangan menimpa report dari
assessment lain.
