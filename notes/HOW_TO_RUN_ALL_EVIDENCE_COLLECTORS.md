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
