# AGENTS.md — Panduan Senior SSIS Performance Engineering

Dokumen ini adalah instruksi kerja untuk agent/engineer yang melakukan assessment,
diagnosis, dan performance tuning SSIS di repository ini. Tujuan utamanya adalah
menghasilkan keputusan tuning yang terukur, dapat ditelusuri ke evidence, dan aman
terhadap functional correctness.

## Konteks Repository

Repository ini bukan aplikasi runtime; ini adalah toolkit evidence dan assessment
untuk SSIS/SSISDB. Artefak utama:

- `Collect-SSISEvidence.ps1`, `New-SSISAssessment.ps1`: collector evidence runtime
  SSISDB dan static package dari ISPAC.
- `Collect-StaticOnly.ps1`: shortcut static-only.
- `config.ps1`: konfigurasi collector; jangan commit credential atau path lokal
  sensitif.
- `assessments/<id>/`: raw evidence hasil assessment.
- `ispac/`: input deployment package; ISPAC diekstrak sebagai ZIP dan DTSX dibaca
  secara XML.
- `queries/`: query export SQL Agent, SSISDB, dan evidence tambahan.
- `FINAL_ASSESSMENT_REPORT.md`: assessment teknis utama.
- `EXECUTIVE_ASSESSMENT_SUMMARY.md`: review/rekonsiliasi eksekutif.
- `PERFORMANCE_TUNING_PLAN.md`: roadmap tuning dari temuan assessment.
- `DTSX_ANTIPATTERN_*.md/csv` dan `ACTIVE_JOB_DTSX_ANTIPATTERN_PRIORITY.*`:
  inventory serta kandidat anti-pattern, bukan bukti bottleneck runtime.
- `SSIS_Tuning_Guide.md`, `GLOSSARY.md`, `priority_glossary.md`: referensi istilah
  dan prinsip tuning.

Jangan menganggap file CSV/XLSX/DOCX/PDF sebagai sumber kebenaran yang setara.
Gunakan data terstruktur dan raw evidence terlebih dahulu, lalu report untuk konteks.

## Source of Truth dan Batasan Saat Ini

Urutan kepercayaan evidence:

1. Raw evidence per execution di `assessments/<id>/`.
2. Evidence executable/message dan hasil static extraction.
3. `FINAL_ASSESSMENT_REPORT.md`.
4. `EXECUTIVE_ASSESSMENT_SUMMARY.md`.
5. Summary, spreadsheet, guide, atau dugaan berdasarkan best practice.

Kondisi penting dari assessment yang ada:

- raw execution extract dibatasi `MaxExecutions = 500`, sedangkan package summary
  merepresentasikan sekitar 5.128 execution; populasi dan observation window harus
  direkonsiliasi sebelum menghitung failure rate/frequency enterprise.
- `execution_component_phases.csv` dan `execution_data_statistics.csv` kosong;
  component-level bottleneck, throughput, rows/sec, dan row-volume correlation belum
  dapat disimpulkan.
- Query Store dinonaktifkan pada first pass; jangan membuat kesimpulan query, index,
  plan, wait, blocking, atau database-side root cause tanpa evidence SQL.
- Sample kecil atau single-run hanya mendukung kesimpulan pada observed execution,
  bukan generalisasi historis.
- `CONFIRMED` berarti kondisi/lokasi terbukti; belum otomatis berarti root cause dan
  solusi sudah terbukti.

## Temuan Awal yang Harus Menjadi Prioritas

Gunakan temuan ini sebagai titik awal, bukan sebagai alasan untuk langsung mengubah
package:

- `Sequence_Table / Sequence_Table / Seq_Staging_SIGAP.dtsx`: execution `1240550`
  berdurasi `6,336.348s`; `\\Package4` menyumbang `6,334.656s`. Lokasi elapsed
  time confirmed, mekanisme belum diketahui.
- `Project_Fact / AWL / Staging.dtsx`: 34 raw execution, total `11,122.319s`,
  P95 `720.6s`; jalur `API to STG` pada execution `1240317` adalah tracing target.
- Runtime target berulang lain: `premi dan lembur monitoring`, SPARTA LHA, DAILY TBS,
  dan DWH Grading Fact. Runtime impact confirmed; component cause belum confirmed.
- Reliability issue confirmed pada `DWH_GRADING_TBS\Staging`,
  `Seq_Staging_WB`, dan `Seq_Staging_NON_SAP`: connection acquisition,
  validation, timeout, missing connection, dan unexpected/failure messages.
- Static Sort, Lookup, Merge, Aggregate, Script, jumlah component tinggi, unused
  output, atau metadata warning adalah investigation clue saja.

## Workflow Assessment dan Tuning

### 1. Tetapkan scope dan baseline

Sebelum menyimpulkan atau mengubah apa pun, catat:

- assessment ID, server, SSISDB folder/project/package, execution ID, observation
  window, parameter/environment, dan sumber data;
- package elapsed, executable elapsed, count, success/failure, median/P95/max bila
  sample memadai, cumulative runtime, dan concurrency/overlap;
- rows/data volume serta component phase hanya jika evidence tersedia;
- apakah metrik berasal dari raw population, summary population, atau sample berbeda.

Jika baseline tidak defensible, action pertama adalah **Establish baseline**, bukan tuning.

### 2. Rekonsiliasi evidence

Cross-check minimal:

- `03_runtime/executions.csv` terhadap `package_runtime_summary.csv`;
- `executable_statistics.csv` terhadap package duration;
- `event_messages.csv`/`operation_messages.csv` terhadap status execution;
- static package key (catalog/folder/project/package) terhadap runtime key;
- SSISDB execution terhadap SQL Agent hanya sebagai candidate mapping sampai command,
  waktu, dan package path diverifikasi.

Jangan menjumlahkan nested executable contribution secara naif karena executable dapat
overlap. Jangan menyebut zero rows/zero warnings jika file kosong; sebutkan **evidence
tidak tersedia**.

### 3. Lokalisasi sebelum optimasi

Pisahkan layer diagnosis:

1. Scheduler/SQL Agent dan overlap workload.
2. SSIS control flow/container/package dependency.
3. Data Flow component dan pipeline buffer.
4. Source/API/destination/provider/connection.
5. SQL/database: query, plan, reads, waits, blocking, I/O.

Gunakan runtime evidence untuk menentukan layer. Static XML hanya menunjukkan desain yang
perlu diperiksa.

### 4. Formulasikan hipotesis

Setiap finding harus memuat `Observation`, `Evidence`, `Bottleneck Location`,
`Root Cause/Hypothesis`, `Confidence`, dan `Validation Method`. Bedakan:

- `CONFIRMED`: kondisi terlihat langsung dari evidence;
- `HIGHLY LIKELY`: beberapa evidence mendukung mekanisme, tetapi causal proof belum
  lengkap;
- `POSSIBLE`: hipotesis yang masuk akal dan wajib diuji;
- `INFORMATIONAL`: inventory/warning tanpa dampak runtime terbukti.

Jangan mengisi Top 10 secara paksa. Temuan lebih sedikit tetapi dapat dipertanggung-
jawabkan lebih baik.

### 5. Uji satu perubahan bermakna pada satu waktu

Urutan eksperimen:

`baseline → satu perubahan → execution comparable → ukur → accept/reject → rollback
atau lanjut`.

Bandingkan package duration, hot executable, median/P95 bila layak, variability, failure
rate, rows/volume, output correctness, dan dampak schedule window. Jangan menjanjikan
persentase improvement tanpa hasil benchmark.

## Aturan Tuning SSIS

### Yang boleh dilakukan setelah evidence cukup

- memperbaiki connection/deployment/validation failure yang telah terbukti, dalam
  controlled test;
- instrumentasi ulang execution target untuk mendapatkan component phase, rows/data
  statistics, dan dependency timing;
- tracing terarah pada `Seq_Staging_SIGAP\\Package4` dan `AWL\\Staging\\API to STG`;
- menguji desain/setting package hanya jika mekanisme relevan sudah terukur dan perubahan
  dapat diisolasi.

### Yang tidak boleh dipreskripsikan secara arbitrer

Jangan langsung mengubah `DefaultBufferSize`, `DefaultBufferMaxRows`,
`AutoAdjustBufferSize`, `EngineThreads`, `MaxConcurrentExecutables`, Lookup cache,
`RowsPerBatch`, `MaximumInsertCommitSize`, `TableLock`, transaction/checkpoint,
parallelism, SQL rewrite, index, atau package decomposition hanya karena best practice umum.

Perubahan konkret memerlukan: setting aktual terverifikasi, runtime symptom yang relevan,
mekanisme yang masuk akal, controlled benchmark, success criteria, dan rollback criteria.

Static anti-pattern handling:

- Lookup → inspect mode, reference query, cache size, miss behavior, rows, dan phase;
- Sort/Merge/Aggregate → inspect kebutuhan fungsional, sorting contract, dan cost;
- Script → inspect code/row-by-row behavior sebelum menyimpulkan;
- unused output/metadata warning → pisahkan housekeeping dari performance claim.

### Reliability versus performance

Catat dua kategori terpisah. Repair connection/validation mengurangi failure dan retry;
manfaat elapsed-time yang mungkin timbul harus dibuktikan terpisah. Jangan mengklaim
reliability fix sebagai performance tuning tanpa before/after metric.

### Database-side discipline

Jika Query Store/SQL evidence belum ada, action yang benar adalah:

> Capture and assess the source query used by executable X.

Bukan langsung membuat index, hint, statistics change, query rewrite, atau server
configuration change. Database-side conclusion harus menyertakan query identity, duration,
reads, plan/waits/blocking bila tersedia.

## Klasifikasi Action dan Prioritas

- `TUNE NOW`: evidence cukup untuk controlled implementation dan benchmark; bukan izin
  perubahan production tanpa test.
- `VALIDATE FIRST`: hipotesis kuat, perlu instrumentation/experiment.
- `INVESTIGATE`: target bermakna tetapi root cause belum jelas.
- `DEFER`: evidence, impact, risk, atau dependency belum membenarkan tindakan.

Prioritas memakai impact runtime/cumulative/frequency/variability/reliability, confidence,
effort, risk, dan dependency. P0 hanya untuk critical demonstrated issue; P1 untuk
high-impact evidence kuat; P2 untuk moderate/uncertain; P3 untuk strategic/preventive
investigation. Rank durasi bukan otomatis P0/P1.

## Collector dan Operasional Repo

Untuk assessment baru:

1. Review `config.ps1`; set `ServerInstance`, `IspacRoot`, lookback, filters, dan
   output root secara eksplisit.
2. First pass gunakan `CollectStatic = $true`, `CollectRuntime = $true`; Query Store
   tetap optional/disabled kecuali scope memang membutuhkan.
3. Jalankan dari PowerShell 4.0+ dengan `New-SSISAssessment.ps1` dan simpan assessment ID
   serta `collector.log`.
4. Verifikasi manifest, row counts, error files, extraction, dan observation window.
5. Jangan menimpa evidence lama. Buat assessment ID/output baru untuk rerun.

Contoh:

```powershell
powershell -ExecutionPolicy Bypass -File .\\New-SSISAssessment.ps1
powershell -ExecutionPolicy Bypass -File .\\New-SSISAssessment.ps1 -AssessmentId EVSET-002
```

`Collect-SSISEvidence.ps1` memakai Windows Shell/.NET ZIP compatibility; jangan
mengganti alur extraction dengan dependency modern tanpa alasan. Perlakukan ISPAC, CSV,
Excel, DOCX, dan PDF sebagai data yang mungkin mengandung informasi sensitif. Jangan
menyalin password/connection string ke report, commit, log, atau prompt.

## Format Output Wajib

Report/finding baru harus menyediakan traceability:

| Field | Isi minimum |
|---|---|
| Finding ID | ID stabil, misalnya `SSIS-TUNE-001` |
| Scope | catalog/folder/project/package/executable/component |
| Observation | fakta terukur dan population |
| Evidence | path file, execution ID, dan kolom/query relevan |
| Confidence | CONFIRMED/HIGHLY LIKELY/POSSIBLE/INFORMATIONAL |
| Action type | TUNE NOW/VALIDATE FIRST/INVESTIGATE/DEFER |
| Baseline | metrik sebelum perubahan |
| Hypothesis | mekanisme, ditandai sebagai hipotesis bila belum terbukti |
| Validation | test comparable dan metric |
| Success/guardrail | improvement serta correctness/reliability constraints |
| Rollback | kondisi penolakan/reversal |

Untuk `PERFORMANCE_TUNING_PLAN.md`, pertahankan urutan Wave 0 measurement, Wave 1
high-confidence, Wave 2 secondary, dan Wave 3 strategic. Sertakan deferred/rejected
recommendations agar keputusan untuk tidak mengubah package tetap terlihat.

## Quality Gate Sebelum Menutup Pekerjaan

- setiap finding dapat ditelusuri ke raw evidence atau dinyatakan sebagai hipotesis;
- raw dan summary population tidak dicampur tanpa rekonsiliasi;
- setiap P0/P1 dan `TUNE NOW` memiliki baseline, benchmark, success criteria, dan
  rollback criteria;
- tidak ada setting SSIS, SQL tuning, atau improvement percentage yang dibuat-buat;
- static anti-pattern tidak dipromosikan menjadi bottleneck tanpa runtime proof;
- component/database conclusion menghormati evidence gap;
- failure/reliability dipisahkan dari performance;
- output correctness, row counts, downstream behavior, dan success rate tidak memburuk;
- perubahan hanya dilakukan pada file yang diminta; evidence dan source ISPAC asli
  dipertahankan;
- `git diff` dan `git status` diperiksa sebelum handoff, dan file generated besar
  tidak diubah tanpa alasan terdokumentasi.
