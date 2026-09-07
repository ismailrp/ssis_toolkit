• Jika ditanya evidence untuk package P1, jawabannya harus menunjukkan rantai bukti berikut:

1. Identitas package dan job

- queries/01_sql_agent_job_steps.csv
- queries/02_sql_agent_job_history.csv
- queries/04_ssis_executions.csv

Bukti yang dicari:

JOB_NAME
STEP_ID / STEP_NAME
Folder / Project / Package
Execution ID
SQL Agent command

Execution ID pada message SQL Agent menjadi penghubung utama antara job step dan SSIS execution.

2. Dampak runtime

- queries/04_ssis_executions.csv
- assessments/EVSET-001/03_runtime/package_runtime_summary.csv
- queries/B02_executable_statistics.csv

Bukti:

- average duration
- maximum duration
- total/cumulative duration
- execution frequency
- failure atau unexpected status
- executable/task yang memakan waktu paling besar

3. Evidence static package

- DTSX_ANTIPATTERN_PACKAGE_FINDINGS.csv
- file .dtsx terkait
- DTSX_ANTIPATTERN_INSPECTION_REPORT.md

Evidence static digunakan untuk mendukung hipotesis, bukan membuktikan bottleneck. Contoh:

CROSS JOIN
SELECT \*
Sort / Aggregate
OLE DB Command
Non-SARGable predicate
Fast Load inactive

4. Evidence operasional

- queries/B05_ssis_event_messages.csv
- queries/B06_ssis_operation_messages.csv
- queries/02_sql_agent_job_history.csv

Bukti:

- connection/validation failure
- retry
- blocking/wait indication
- package warning/error
- job failure atau retry

Contoh jawaban untuk DWH_GRADING_TBS / Fact.dtsx:

> Package dijalankan oleh job AI Grading, step 2 Fact. Mapping dikonfirmasi melalui Execution ID pada SQL Agent
> history. Terdapat 48 execution dengan average sekitar 56,6 menit dan maximum sekitar 73,1 menit pada package runtime
> summary. Executable FACT_AI_GRADING_PENERIMAAN_TBS menghabiskan hampir seluruh durasi package. Static query
> menunjukkan join terhadap beberapa tabel staging, predicate LEFT(nomor_tiket,2)='GR', dan ORDER BY tanggal_masuk.
> Namun, belum ada component-phase, rows-sent, execution plan, atau Query Store evidence, sehingga lokasi dampaknya
> confirmed tetapi root cause masih perlu divalidasi.

Format evidence P1 yang ideal:

Package:
Job / Step:
Execution ID:
Runtime:
Frequency:
Failure rate:
Hot executable:
Static indicators:
Operational messages:
Confidence:
Remaining evidence gap:
Recommended next validation:
