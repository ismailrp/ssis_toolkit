# SSIS Package to SQL Agent Job/Step Mapping

## Purpose

This mapping relates packages in the performance reports to the job and step names found in:

`assessments/EVSET-001/03_runtime/list_job_running.csv`

The file contains 311 job-step rows with fields for `JOB_NAME`, `STEP_ID`, `STEP_NAME`, duration history, execution count, failures, and schedule type.

## Important qualification

The job-list CSV does not contain an SSIS `execution_id`, project name, package path, or job-step command text. Therefore:

- **High confidence** means the job and step names align directly with the package/project naming.
- **Medium confidence** means the names strongly suggest a relationship but do not prove it.
- **Low confidence / unresolved** means the step name is generic or multiple jobs are plausible.
- The job-list snapshot shows dates around 2026-08-20, while the raw SSIS execution sample covers 2026-09-01 to 2026-09-02. Job statistics must not be combined directly with raw execution statistics without a time-aligned join.

## Mapping for priority workloads

| Folder | Project | SSIS Package | Candidate SQL Agent Job | Step ID | Step Name | Confidence | Reason / Limitation |
|---|---|---|---|---:|---|---|---|
| Project_Fact | AWL | `Staging.dtsx` | `AWL` | 1 | `Staging` | HIGH | Job and step names align with project/package. Generic step name exists under other jobs, but job `AWL` is the direct project match. |
| Project_Fact | premi dan lembur monitoring | `DWH_STG to DWH_DM.dtsx` | `Premi dan Lembur` | 1 | `DWH_STG to DWH_DM` | HIGH | Exact semantic match; summary also identifies this as a material workload. |
| Project_Fact | SPARTA_PROJECT | `FACT_SPARTA_LHA_NEW.dtsx` | `SPARTA FACT 4T` | 3 | `Dimensi Sparta LHA` | LOW | Related subject area, but the step name does not match the package name. Confirm from the job-step command. |
| Project_Fact | DAILY_DASHBOARD_PROJECT | `FACT_DD_TBS.dtsx` | `Daily Opr - Produksi TBS` | 5 | `Fact Monitoring TBS` | LOW | Subject-area candidate only; generic `Fact` steps occur under multiple jobs. |
| Project_Fact | DWH_GRADING_TBS | `Fact.dtsx` | `AI Grading` | 1 | `Staging` | LOW | Possible subject-area relationship, but no direct package-name match. |
| Controllable Profit | ControllableProfit | `STG to DWH.dtsx` | `Controllable Profit` | 4 | `STG to DWH` | HIGH | Exact job/project and step/package semantic match. |
| Sequence_Table | Sequence_Table | `Seq_Staging_SIGAP.dtsx` | `SEQUENCE_TABLE_SIGAP` | 1 | `Staging` | HIGH | Job name matches project/package subject and step matches package function. |
| Project_Fact | DWH_LHM | `Fact Rekap.dtsx` | `Turnover Staff BGA` or `Turnover Non Staff BGA` | 3 | `Fact Rekap` | MEDIUM | Exact step name, but two jobs share the same step name; package/project identity is not present. |
| Project_Fact | SPARTA_PROJECT | `FACT_SPARTA_FISIK_PREMI.dtsx` | `SPARTA FACT 4T` | 7 | `Fact Sparta Fisik Premi` | HIGH | Exact step/package semantic match. |
| Sequence_Table | Sequence_Table | `Seq_Staging_SPARTA_4T.dtsx` | `SEQUENCE_TABLE_SPARTA_4T` | 1 | `SEQ_STAGING_SPARTA_4T` | HIGH | Exact job and step naming match. |
| Project_Fact | JOURNAL_SPARTA | `FACT_JOURNAL_PAYROLL.dtsx` | `SPARTA FACT` | 4 | `Fact Sparta Jurnal Payroll` | HIGH | Exact subject and step semantic match. |
| Project_Fact | DWH_LKK_PROJECT_NEW | `FACT_LKK.dtsx` | `LAPORAN KEUANGAN KEBUN (LKK)` | 4 | `Fact` | MEDIUM | Likely generic LKK fact step; other LKK `Fact`-like steps exist. Command text is needed. |
| Project_Fact | DWH_PLASMA_GAPOKTAN | `Fact.dtsx` | `LAPORAN KEUANGAN KEBUN (LKK)` | 10 | `Fact Plasma Gapoktan` | HIGH | Strong project/step subject match. |
| Project_Fact | INVESTOR_RELATIONS_PROJECT | `PS_AS.dtsx` | Unresolved | — | — | NONE | No job/step name in the CSV provides a defensible direct match. |
| Sequence_Table | Sequence_Table | `Seq_Staging_SPARTA.dtsx` | `SEQUENCE_TABLE_SPARTA` | 1 | `SEQ_STAGING_SPARTA` | HIGH | Exact job and step naming match. |
| Project_Fact | Segregation | `Segregation.dtsx` | `Segregation` | 2 | `Segregation` | HIGH | Exact job and step name; the same job also has staging and SSAS steps, so step 2 is the direct package-name match. |
| Project_Fact | SPARTA_PROJECT | `FACT_SPARTA_PAYROLL.dtsx` | `SPARTA FACT` | 3 | `Fact Sparta Payroll` | HIGH | Exact step/package semantic match. |
| Project_Fact | LKK Dashboard | `FACT_LKK_DASHBOARD.dtsx` | `LAPORAN KEUANGAN KEBUN (LKK)` | 12 | `Fact LKK Dashboard` | HIGH | Exact step/package semantic match. |
| Project_Fact | Lap Prod TBS CPO PK | `Laporan Produksi TBS CPO PK.dtsx` | `Lap Prod TBS CPO PK` | 1 | `Lap Prod TBS CPO PK` | HIGH | Exact job and step name match. |
| Project_Fact | PPH21_DJP | `FACT_PPH_ANNUAL_SPLIT.dtsx` | Unresolved | — | — | NONE | No direct package/job-step match identified. |
| Project_Fact | INTERNAL_AUDIT | `FACT_INTERNAL_AUDIT.dtsx` | `Internal Audit` | 1 | `Internal Audit` | MEDIUM | Job/step subject matches project, but package filename differs. |
| Project_Fact | PRPOGR_Dashboard | `Fact - fact_pr_po_gr.dtsx` | Unresolved | — | — | NONE | Generic `Fact` steps are ambiguous; no direct match. |

## Failure-prone workloads

| SSIS Package | Candidate Job/Step | Evidence Relationship | Confidence |
|---|---|---|---|
| `DWH_GRADING_TBS\Staging.dtsx` | `AI Grading`, step 1 `Staging` | Subject-area and step-function match only | LOW |
| `Seq_Staging_WB.dtsx` | Unresolved | No direct WB package/step match identified in the job list | NONE |
| `Seq_Staging_NON_SAP.dtsx` | `SEQUENCE_TABLE_NON_SAP`, likely staging step if present | Requires exact row/command verification; not used as a confirmed mapping here | LOW |
| `MONITORING_TICKET_WB\STAGING.dtsx` | `MONITORING_TICKET_WB`, likely staging step if present | Requires package/step command verification | LOW |
| `PS_AS.dtsx` | Unresolved | No direct match | NONE |

## Strongly mapped jobs and steps from the report

The following mappings are the most useful for immediate operations review:

| Job | Step ID | Step | Related report workload |
|---|---:|---|---|
| `SEQUENCE_TABLE_SIGAP` | 1 | `Staging` | `Sequence_Table / Sequence_Table / Seq_Staging_SIGAP.dtsx` |
| `AWL` | 1 | `Staging` | `Project_Fact / AWL / Staging.dtsx` |
| `Premi dan Lembur` | 1 | `DWH_STG to DWH_DM` | `Project_Fact / premi dan lembur monitoring / DWH_STG to DWH_DM.dtsx` |
| `Controllable Profit` | 4 | `STG to DWH` | `Controllable Profit / ControllableProfit / STG to DWH.dtsx` |
| `SEQUENCE_TABLE_SPARTA` | 1 | `SEQ_STAGING_SPARTA` | `Sequence_Table / Sequence_Table / Seq_Staging_SPARTA.dtsx` |
| `SEQUENCE_TABLE_SPARTA_4T` | 1 | `SEQ_STAGING_SPARTA_4T` | `Sequence_Table / Sequence_Table / Seq_Staging_SPARTA_4T.dtsx` |
| `SPARTA FACT` | 3 | `Fact Sparta Payroll` | `Project_Fact / SPARTA_PROJECT / FACT_SPARTA_PAYROLL.dtsx` |
| `SPARTA FACT` | 4 | `Fact Sparta Jurnal Payroll` | `Project_Fact / JOURNAL_SPARTA / FACT_JOURNAL_PAYROLL.dtsx` |
| `SPARTA FACT 4T` | 7 | `Fact Sparta Fisik Premi` | `Project_Fact / SPARTA_PROJECT / FACT_SPARTA_FISIK_PREMI.dtsx` |
| `Segregation` | 2 | `Segregation` | `Project_Fact / Segregation / Segregation.dtsx` |
| `LAPORAN KEUANGAN KEBUN (LKK)` | 10 | `Fact Plasma Gapoktan` | `Project_Fact / DWH_PLASMA_GAPOKTAN / Fact.dtsx` |
| `LAPORAN KEUANGAN KEBUN (LKK)` | 12 | `Fact LKK Dashboard` | `Project_Fact / LKK Dashboard / FACT_LKK_DASHBOARD.dtsx` |
| `Lap Prod TBS CPO PK` | 1 | `Lap Prod TBS CPO PK` | `Project_Fact / Lap Prod TBS CPO PK / Laporan Produksi TBS CPO PK.dtsx` |

## What is still required for a definitive mapping

For each SQL Agent step, export the step command and correlate it with the SSIS catalog path:

`Folder / Project / Package`

The strongest confirmation is a job-step command containing the package path or a time-aligned SQL Agent history record that overlaps the SSIS `execution_id` start/end time. The current `list_job_running.csv` is sufficient for candidate mapping, but not for proving which job launched each captured SSIS execution.

## Source

`assessments/EVSET-001/03_runtime/list_job_running.csv`

The mapping does not modify the evidence file or any of the three assessment reports.
