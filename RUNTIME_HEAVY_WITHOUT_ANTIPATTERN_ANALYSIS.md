# Runtime-Heavy Packages Without Static Anti-Pattern Findings

Scope: packages with average runtime at least 10 minutes in `package_runtime_summary.csv` and zero findings after correcting `DestinationCommitSizeSetting`. “No anti-pattern” means no configured static rule matched; it does not mean the package is efficient.

## Priority overview

| Priority | Package | Executions | Average | Maximum | Main interpretation |
|---|---|---:|---:|---:|---|
| P1 | `Project_Fact / DWH_GRADING_TBS / Fact.dtsx` | 48 | 56.6 min | 73.1 min | One main Data Flow occupies almost the complete package; source join/filter/order and data volume are primary suspects. |
| P1 | `Controllable Profit / ControllableProfit / STG to DWH.dtsx` | 14 | 59.7 min | 74.0 min | Multiple fact branches each consume substantial time; likely source/database work or large input volume. |
| P1 | `LKK Phase 2 / LKK Phase 2 / STG to DWH.dtsx` | 14 | 48.2 min | 69.6 min | Main `STG to DWH` task contains long fact branches; investigate source SQL and serial/parallel design. |
| P1 | `Project_Fact / premi dan lembur monitoring / DWH_STG to DWH_DM.dtsx` | 67 | 29.9 min | 63.4 min | High frequency, high cumulative runtime, and 22 non-successes; reliability and workload overlap need priority review. |
| P1 | `Sequence_Table / Sequence_Table / Seq_BSEG 1.dtsx` | 5 | 48.2 min | 62.8 min | Small sample but consistently long summary runtime; obtain component/task detail before tuning. |
| P2 | `Project_Fact / PRPOGR_Dashboard / Fact - fact_pr_po_gr.dtsx` | 14 | 30.6 min | 57.4 min | Historical/period processing branch is dominant; validate range filtering and incremental-load behavior. |
| P2 | `Project_Fact / PEMAKAIAN_SOLAR / Fact_Pemakaian_Solar v2.dtsx` | 14 | 21.5 min | 24.1 min | Stable but consistently expensive Data Flow; likely volume, source SQL, or destination throughput. |
| P2 | `tesss / premi dan lembur monitoring / DWH_STG to DWH_DM.dtsx` | 2 | 21.7 min | 42.7 min | Duplicate/secondary deployment with too few observations; validate whether it is still active and representative. |
| P2 | `Project_Fact / DWH_TURNOVER_BGA / Fact Rekap.dtsx` | 1 | 18.3 min | 18.3 min | Single observation; treat as investigation candidate, not a proven stable average. |
| P2 | `Project_Fact / Lap Prod TBS CPO PK / Laporan Produksi TBS CPO PK.dtsx` | 14 | 16.0 min | 31.0 min | Several fact branches contribute to runtime; check source volume and whether all branches must run serially. |
| P2 | `Project_Fact / DWH_LHM / Fact Rekap.dtsx` | 57 | 15.0 min | 39.4 min | Frequent package with high cumulative cost and variability; investigate input volume, date range, and concurrency. |

## Package-specific reasoning and recommendations

### DWH_GRADING_TBS / Fact.dtsx

The package has 48 executions with an average of 56.6 minutes. Executable statistics show `FACT_AI_GRADING_PENERIMAAN_TBS` consuming nearly the complete package duration. The source query joins four staging/reference tables, applies `LEFT(nomor_tiket,2) = 'GR'`, and orders by `tanggal_masuk`.

Recommendations:

- Test `nomor_tiket LIKE 'GR%'` against the current predicate and compare the execution plan.
- Verify indexes and statistics on `nomor_tiket`, `DocumentNumber`, `PlantId`, and `DivisionId`.
- Confirm uniqueness/cardinality of join keys to exclude row multiplication.
- Remove `ORDER BY tanggal_masuk` unless the downstream flow requires ordered input.
- Capture component phases and data statistics for one normal and one slow execution.

### Controllable Profit / STG to DWH

Executable statistics show long branches such as `FACT_CONTROLLABLE_PROFIT_NON_COST` and `FACT_CONTROLLABLE_PROFIT_COST_VW`. The runtime is therefore likely distributed across multiple fact loads rather than caused by one detected SSIS anti-pattern.

Recommendations:

- Profile each fact branch separately with component phases and row counts.
- Check whether branches are independent and can safely run in parallel.
- Validate source view complexity, date filters, indexes, and input row volume.
- Compare branch duration against destination insert and index-maintenance time.

### LKK Phase 2 / STG to DWH

The main task contains long branches including `FACT_LKK_PHASE_2_BY_TM` and `FACT_LKK_PHASE_2_BY_TOTAL`. This points to source/database processing, large aggregation, or serial branch execution; no static rule proves which one.

Recommendations:

- Capture SQL text, waits, logical reads, and row counts while the two branches run.
- Check whether both branches rescan the same source data and can share a staged result.
- Validate aggregation and date-range predicates in the source queries.

### premi dan lembur monitoring / DWH_STG to DWH_DM

This package runs frequently and has 22 non-successes in the summary evidence. Its maximum is more than twice its average, so runtime variability and operational contention are both plausible.

Recommendations:

- Treat reliability and performance as separate workstreams.
- Correlate slow runs with concurrent jobs, blocking, waits, and source row volume.
- Validate the 22 non-successes against event messages and job history.
- Investigate both `Project_Fact` and `tesss` deployments separately; do not combine their averages.

### Seq_BSEG 1

The average is high, but only five executions are represented. The current evidence does not provide enough component-level detail to identify the cause.

Recommendations:

- Collect at least five comparable executions with executable/component statistics.
- Confirm whether the package performs a full historical load or waits on an upstream sequence.
- Review source extraction range, destination indexes, and concurrent sequence-table jobs.

### PRPOGR Dashboard / Fact - fact_pr_po_gr

Executable statistics show the `PRPOGR<2024` branch and its Data Flow task as major contributors. This is consistent with historical-range processing or repeated scans of older data.

Recommendations:

- Verify that the `PRPOGR<2024` branch uses a bounded and selective date/filter predicate.
- Check whether historical data can be loaded incrementally or partitioned.
- Review source and destination indexes and row counts for each period branch.

### Pemakaian Solar / Fact_Pemakaian_Solar v2

The package is consistently around 21.5 minutes, with a maximum around 24 minutes. Stable duration suggests repeatable input volume or a fixed database/destination cost rather than a sporadic failure.

Recommendations:

- Measure source rows, rows sent, destination rows, and source/destination waits.
- Compare source extraction time with destination Fast Load time.
- Review repeated joins/calculations across the Solar and EHP 8 flows.

### DWH_TURNOVER_BGA / Fact Rekap

Only one execution is available. The 18.3-minute duration is useful for triage but insufficient to establish a reliable average or trend.

Recommendations:

- Do not make a production change from this single observation.
- Capture repeat runs and correlate duration with input period and concurrent jobs.

### Lap Prod TBS CPO PK / Laporan Produksi TBS CPO PK

Executable statistics show multiple fact branches, including CPO and TBS flows. The package is a multi-branch workload whose total time can be driven by serial orchestration or the slowest branch.

Recommendations:

- Compare branch durations and check precedence constraints for unnecessary serialization.
- Validate source date filters and row volume.
- Confirm destination indexes and commit/locking behavior during Fast Load.

### DWH_LHM / Fact Rekap

This package has 57 executions and a maximum much higher than its average. It is therefore a good cumulative-impact and variability target even though no static anti-pattern was found.

Recommendations:

- Correlate duration with period, input row count, and concurrent job activity.
- Investigate the `FACT_REKAP_LHM` executable during slow runs.
- Capture waits and active SQL; Query Store is unavailable in the captured environment.

## Overall conclusion

The leading explanation for these packages is not a single DTSX anti-pattern. The remaining likely causes are data volume, source SQL/index plans, destination throughput, serial orchestration, concurrent jobs, blocking, and insufficient component-level evidence.

The next evidence collection should prioritize `DWH_GRADING_TBS`, `Controllable Profit`, `LKK Phase 2`, `premi`, and `DWH_LHM`, using active requests/waits plus SSIS component phases and data statistics where available.
