# Handoff — Finding DOCX SQL Traceability dan Planning Targets

Tanggal: 2026-09-11  
Repository: `C:\Projects\sql\ssis_toolkit`  
Assessment: `assessments/EVSET-45D-COMPLETE`

## Tujuan sesi

1. Memperbaiki hilangnya nama komponen SQL pada DOCX finding, khususnya `BUDGET_BGFIP_SUM` pada Finding-003 `PS_AS.dtsx`.
2. Menambahkan target optimasi sementara yang dapat disajikan kepada client untuk finding ber-impact tinggi tanpa menjadikannya janji hasil tuning.

Tidak ada DTSX atau ISPAC sumber yang diubah.

## Diagnosis Finding-003

Raw package:

`assessments/EVSET-45D-COMPLETE/01_static_packages/extracted/SSISDB/Project_Fact/INVESTOR_RELATIONS_PROJECT/PS_AS.dtsx`

Static scan menemukan `CartesianCrossJoin = 11` dan `SELECT* = 2`. Komponen `BUDGET_BGFIP_SUM` memiliki `SqlCommand` dengan 4 `CROSS JOIN` dan 1 `SELECT *`.

Nama tersebut sebelumnya hilang karena scanner V12 menghitung heuristic SQL dari gabungan SQL package, tetapi `anti_pattern_components` hanya diisi untuk komponen pipeline. Kategori SQL masuk ke report, sedangkan lokasi komponennya tidak ikut masuk.

Komponen/query produksi yang sebelumnya diasumsikan bernama `PRODUKSI_SPB_SUM` tidak ada dengan nama tersebut dalam raw DTSX. Evidence aktual menunjukkan:

- nama komponen SSIS: `AKTUAL - SPB_BLOK`;
- sumber SQL: `StagingDB.bps.SPB_BLOK`;
- 4 `CROSS JOIN`;
- 1 `SELECT *`.

Report menggunakan nama traceable `AKTUAL - SPB_BLOK`. `PRODUKSI_SPB_SUM` berasal dari narasi/template lama, bukan raw evidence saat ini.

## Perubahan kode

### `Upgrade-DTSXAntiPatternScan.ps1`

Ditambahkan `Add-SqlDetails` untuk mengasosiasikan heuristic SQL dengan nama component pemilik SQL. Rule yang sekarang memiliki detail lokasi:

- `SELECT*`, `CartesianCrossJoin`, dan `ImplicitCartesianJoin`;
- `NonSargableFunctionPredicate` dan `OnTheFlyFunctionExpression`;
- `NestedViewReference` dan `PivotWindowFunction`;
- `SqlUnionDistinct`, `SqlUnionAll`, dan `NoLockAdvisory`;
- `FullReloadIndicator`.

Contoh output:

```text
SELECT*:BUDGET_BGFIP_SUM
CartesianCrossJoin:BUDGET_BGFIP_SUM
SELECT*:AKTUAL - SPB_BLOK
CartesianCrossJoin:AKTUAL - SPB_BLOK
```

Hitungan package-level tidak diubah; perubahan hanya menambah traceability lokasi.

### `New-DTSXFindingDocuments.ps1`

Ditambahkan `Get-PlanningTarget`. Target numerik hanya ditambahkan jika priority `P1`, baseline duration lebih besar dari nol, serta finding bukan evidence mapping gap atau runtime hotspot tanpa static explanation.

Isi target pada DOCX:

- baseline observed;
- target utama client 20%;
- target duration dan estimasi saving;
- minimum acceptance 10% dan stretch target 30%;
- confidence `LOW / POSSIBLE`;
- minimal 3 comparable executions;
- output correctness/reliability guardrail;
- rollback/reject jika correctness berubah atau median improvement kurang dari 10%.

Angka tersebut harus selalu disebut **planning estimate**, bukan predicted atau guaranteed saving. Target bukan bukti bahwa static clue merupakan bottleneck runtime.

## Artefak yang diregenerasi

- `results/DTSX_ANTIPATTERN_PACKAGE_FINDINGS_EVSET-45D-COMPLETE-V12.csv`
- `results/DTSX_ANTIPATTERN_INSPECTION_REPORT_EVSET-45D-COMPLETE-V12.md`
- `results/ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_EVSET-45D-COMPLETE-V12.csv`
- `results/ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY_EVSET-45D-COMPLETE-V12.md`
- mismatch dan command/time candidate CSV V12
- `results/DTSX_AGGREGATE_REPORT_EVSET-45D-COMPLETE-V12.csv`
- 167 generated DOCX di `results/package_findings_detail/`

Folder DOCX berisi 168 file karena ada satu template/legacy document tambahan: `SSIS Finding-001-PS_AS_dtsx-Investor Relation v1.0a.docx`.

Artefak `results/` diabaikan Git. File sudah berubah secara lokal meskipun tidak tampil di `git status`.

## Validasi

- Static scan: 781 package, 0 parse errors.
- Aggregate report: 167 rows.
- Priority distribution: P1 = 87, P2 = 4, P3 = 76.
- DOCX dengan planning target: 86.
- Satu P1 tanpa target adalah `CHECK_QUERY_DATA.dtsx`, karena tidak memiliki static explanation pendukung.
- Finding-003 memuat `BUDGET_BGFIP_SUM`, `AKTUAL - SPB_BLOK`, target 20%, minimum 10%, dan stretch 30%.
- `git diff --check` selesai tanpa whitespace error.

Target Finding-003:

| Metric | Nilai |
|---|---:|
| Baseline observed | 4.156,12 detik / 69,27 menit |
| Target utama | 20% |
| Target duration | maksimum 3.324,90 detik / 55,42 menit |
| Estimasi saving | 831,22 detik / 13,85 menit |
| Minimum acceptance | 10% |
| Stretch target | 30% |
| Confidence | LOW / POSSIBLE |

## Perintah regenerasi

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Upgrade-DTSXAntiPatternScan.ps1 `
  -AssessmentPath .\assessments\EVSET-45D-COMPLETE `
  -OutputPath .\results `
  -ReportSuffix EVSET-45D-COMPLETE-V12

powershell -NoProfile -ExecutionPolicy Bypass -File .\build_active_job_antipattern_report.ps1 `
  -AssessmentPath .\assessments\EVSET-45D-COMPLETE `
  -OutputPath .\results `
  -StaticFindingsPath .\results\DTSX_ANTIPATTERN_PACKAGE_FINDINGS_EVSET-45D-COMPLETE-V12.csv `
  -ReportSuffix EVSET-45D-COMPLETE-V12 `
  -IncludeCommandTimeCandidates

powershell -NoProfile -ExecutionPolicy Bypass -File .\build_dtsx_aggregate_report.ps1 `
  -ReportPath .\results `
  -OutputPath .\results `
  -ReportSuffix EVSET-45D-COMPLETE-V12

powershell -NoProfile -ExecutionPolicy Bypass -File .\New-DTSXFindingDocuments.ps1 `
  -AggregateReportPath .\results\DTSX_AGGREGATE_REPORT_EVSET-45D-COMPLETE-V12.csv `
  -TemplatePath '.\results\package_findings_detail\SSIS Finding-001-PS_AS_dtsx-Investor Relation v1.0a.docx' `
  -OutputPath .\results\package_findings_detail `
  -Version v1.0a
```

Full scan dan regenerasi 167 DOCX membutuhkan beberapa menit. DOCX generation membutuhkan Microsoft Word COM dan dapat gagal jika template atau target sedang terbuka di Word.

## Git/worktree saat handoff

Perubahan kedua script sudah berada pada commit berikut:

```text
6a6c4ed update scanner
```

Worktree saat note dibuat hanya menunjukkan handoff note ini sebagai file baru:

```text
?? notes/HANDOFF_FINDING_DOCX_SQL_TRACEABILITY_AND_TARGETS.md
```

Periksa `git diff`, `git status`, dan isi commit tersebut sebelum handoff berikutnya. Artefak di `results/` tetap tidak terlihat karena diabaikan Git.

## Evidence boundary dan langkah lanjutan

- Static CROSS JOIN membuktikan desain dan lokasi query, bukan runtime root cause.
- Component phase dan row statistics belum tersedia; kontribusi elapsed per component belum dapat dihitung.
- Target 20% adalah angka client-facing untuk eksperimen, bukan improvement guarantee.
- Jangan mengubah query, index, buffer, parallelism, atau setting SSIS sebelum query plan, reads, waits/blocking, row volume, dan controlled benchmark tersedia.
- Langkah berikut yang paling defensible adalah menangkap component elapsed/row volume serta query plan untuk `BUDGET_BGFIP_SUM` dan `AKTUAL - SPB_BLOK`, lalu mengganti planning estimate dengan hasil benchmark aktual.
