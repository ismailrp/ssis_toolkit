# SSIS Performance Assessment, Bottleneck Analysis & Tuning Roadmap

## 1. Executive Summary

Assessment classification: **NEEDS ATTENTION**.

The evidence demonstrates a mixed workload with several multi-hour packages and a small but material reliability problem. The raw execution extract contains 500 executions from 2026-09-01 10:05:00 +07:00 through 2026-09-02 09:55:16 +07:00: 489 succeeded, 8 failed, and 3 ended unexpectedly. The 500-row result is consistent with the configured `MaxExecutions=500`; it should be treated as a capped sample rather than a complete historical population.

What is proven:

- `Sequence_Table\Sequence_Table\Seq_Staging_SIGAP.dtsx` ran for 6,336.348 seconds (105.6 minutes) in execution `1240550`. Its `\\Package4` executable ran for 6,334.656 seconds, demonstrating that elapsed time was concentrated in that control-flow branch.
- `Project_Fact\AWL\Staging.dtsx` was the largest cumulative raw-runtime consumer: 34 successful executions totaling 11,122.319 seconds (3.09 hours), with a 327.1-second average and 720.6-second P95.
- Other large cumulative consumers were `premi dan lembur monitoring\DWH_STG to DWH_DM.dtsx` (10,284.305 seconds), `SPARTA_PROJECT\FACT_SPARTA_LHA_NEW.dtsx` (10,133.694 seconds), `DAILY_DASHBOARD_PROJECT\FACT_DD_TBS.dtsx` (8,116.303 seconds), and `DWH_GRADING_TBS\Fact.dtsx` (7,205.128 seconds).
- Reliability failures are concentrated in `DWH_GRADING_TBS\Staging.dtsx` (3 of 5 executions failed), `Sequence_Table\Seq_Staging_WB.dtsx` (3 of 4 failed), and `Sequence_Table\Seq_Staging_NON_SAP.dtsx` (1 failure/unexpected termination in 4 executions). The messages identify connection acquisition, login timeout, missing connection-manager, and validation failures.

What still requires validation:

- The causal mechanism inside the long-running packages is not conclusively identified because component phases and data statistics are empty.
- Static Sort, Lookup, Merge, and Aggregate indicators identify investigation targets, but do not prove that those components caused the elapsed time.
- Database-side performance cannot be conclusively assessed because Query Store was disabled and no database performance evidence was collected.

The first tuning actions should be: investigate `Seq_Staging_SIGAP` / `\\Package4`, then the high-cumulative `AWL\Staging` workload, and separately remediate the recurring connection and validation failures. Every change should be benchmarked with comparable input volume and success/failure measurements.

## 2. Evidence Coverage & Assessment Confidence

| Evidence Category | Status | Records / Objects | Assessment Use | Limitation |
|---|---|---:|---|---|
| ISPAC inventory | AVAILABLE | 107 ISPACs | Source package coverage and extraction status | All 107 records report `ExtractStatus=OK`; source snapshot is not necessarily the deployed runtime state |
| Static package summary | AVAILABLE | 781 packages | Package complexity and design indicators | All 781 parsed `OK`; indicators do not contain component runtime timings |
| SSISDB package/project inventory | AVAILABLE | 20 folders, 109 projects, 938 packages | Deployed catalog scope and static/runtime comparison | Inventory is broader than the 500-execution sample |
| Executions | AVAILABLE, CAPPED | 500 executions | Raw duration, status, frequency, cumulative runtime | Collection configured with `MaxExecutions=500`; complete history cannot be inferred |
| Package runtime summary | AVAILABLE, DIFFERENT POPULATION | 200 summary rows; 5,128 summarized executions | Cross-check and broader package ranking | Summary totals do not reconcile to the 500 raw rows, so metrics are not interchangeable |
| Executable statistics | AVAILABLE | 8,351 rows | Locate elapsed time within packages | Executables can overlap; durations must not be summed as package elapsed time |
| Slow executables | AVAILABLE | 1,000 rows | Long executable-path ranking | It is a ranked/capped extract and repeats parent/child paths |
| Component phases | EMPTY / NOT AVAILABLE | 0 rows | Component-level timing | No component bottleneck can be confirmed |
| Data statistics | EMPTY / NOT AVAILABLE | 0 rows | Rows sent and throughput | No defensible rows/sec or volume correlation is possible |
| Event messages | PARTIAL / CAPPED | 20,000 rows | Runtime errors and warnings | Row cap limits complete message-history coverage |
| Operation messages | PARTIAL / CAPPED | 20,000 rows | Operational error/warning corroboration | Row cap limits complete message-history coverage |
| Query Store evidence | NOT COLLECTED | `CollectQueryStore=False`; no Query Store folder/evidence | Database-side correlation | SQL duration, reads, plans, blocking, and resource pressure are unavailable |

Collection integrity observations:

- ISPAC extraction completed successfully for all 107 inventory records, and all 781 static package summaries have `ParseStatus=OK`.
- The static package set and runtime package keys do not fully align: 155 of the 183 runtime package keys have an exact static-summary match, while 28 do not. This limits static correlation for those 28 workloads.
- The 200-row package summary reports 5,128 executions, whereas raw execution evidence contains 500 executions. This is evidence of different query populations or collection limits, not a data point that can be silently combined.
- `environment_variables.csv` and `environments.csv` are empty. This prevents assessment of deployed environment values and their relationship to runtime behavior.
- Empty component/data files are evidence gaps, not evidence that no component-level bottlenecks exist.

## 3. SSIS Environment & Workload Overview

The collector ran against `BGASVR-DWH-DEV`, SQL Server 13.0.5026.0, Enterprise Edition, using Windows PowerShell 4.0. Collection was configured for a 14-day lookback, static collection enabled, runtime collection enabled, messages enabled, and Query Store disabled. The captured raw execution window is only approximately 24 hours.

The catalog inventory contains 20 folders, 109 projects, and 938 packages. Static evidence contains 107 ISPACs and 781 parsed packages. The raw runtime extract covers 73 folder/project combinations and 183 unique folder/project/package keys.

Across the raw extract, total observed package elapsed time is 159,399.680 seconds (44.3 hours). This is cumulative elapsed time across executions and must not be interpreted as wall-clock duration because executions may overlap.

## 4. Runtime Performance Baseline

### Longest-running packages

The longest observed execution was `Seq_Staging_SIGAP.dtsx` at 6,336.348 seconds. It was followed by `FACT_LKK.dtsx` at 4,219.975 seconds, failed `PS_AS.dtsx` at 4,042.260 seconds, `DWH_GRADING_TBS\Fact.dtsx` at 3,748.054 seconds, and `ControllableProfit\STG to DWH.dtsx` at 3,675.128 seconds.

### Largest cumulative consumers

The largest raw cumulative consumers were `AWL\Staging.dtsx` (11,122.319 seconds), `premi dan lembur monitoring\DWH_STG to DWH_DM.dtsx` (10,284.305 seconds), `SPARTA_PROJECT\FACT_SPARTA_LHA_NEW.dtsx` (10,133.694 seconds), `DAILY_DASHBOARD_PROJECT\FACT_DD_TBS.dtsx` (8,116.303 seconds), and `DWH_GRADING_TBS\Fact.dtsx` (7,205.128 seconds).

### Most frequently executed packages

`AWL\AWL_Warning.dtsx`, `AWL\Fact.dtsx`, and `AWL\Staging.dtsx` each ran 34 times. `DWH_SMALLER_FACT\CHECK_QUERY_DATA.dtsx` ran 24 times. Frequency makes `AWL\Staging.dtsx` a higher operational tuning candidate than a single-run package with a longer individual duration.

### Most unstable packages

Among packages with at least three samples, the largest relative runtime spread was observed in `DWH_SMALLER_FACT\CHECK_QUERY_DATA.dtsx` (24 runs; average 25.7 seconds, median 5.4 seconds, P95 180.9 seconds, maximum 186.5 seconds), `AWL\Fact.dtsx` (34 runs; coefficient of variation approximately 1.54), and `AWL\AWL_Warning.dtsx` (34 runs; coefficient of variation approximately 1.46). These are runtime-variability findings; the evidence does not identify the cause.

### Failure-prone packages

The raw sample has an overall failure/unexpected rate of 11/500 (2.2%). The highest package-level rates are `DWH_GRADING_TBS\Staging.dtsx` at 3/5 (60%), `Sequence_Table\Seq_Staging_WB.dtsx` at 3/4 (75%), `MONITORING_TICKET_WB\STAGING.dtsx` at 1/3 (33.3%), and `INVESTOR_RELATIONS_PROJECT\PL_BS.dtsx` at 1/2 (50%). These are reliability priorities; failure alone does not prove a performance bottleneck.

## 5. Runtime Performance Ranking

P95 is shown only where the raw sample is large enough to make it useful for comparison. For samples below five, P95 is `N/A` rather than presenting a misleading percentile.

| Rank | Folder | Project | Package | Executions | Avg | Median | P95 | Max | Cumulative Runtime | Failure Rate | Runtime Stability | Priority |
|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| 1 | Project_Fact | AWL | Staging.dtsx | 34 | 327.1s | 276.1s | 720.6s | 859.2s | 3.09h | 0% | CV 0.53 | P1 |
| 2 | Project_Fact | premi dan lembur monitoring | DWH_STG to DWH_DM.dtsx | 5 | 2,056.9s | 2,014.6s | 2,710.9s | 2,710.9s | 2.86h | 0% | CV 0.22 | P1 |
| 3 | Project_Fact | SPARTA_PROJECT | FACT_SPARTA_LHA_NEW.dtsx | 5 | 2,026.7s | 1,847.4s | 2,505.3s | 2,505.3s | 2.81h | 0% | CV 0.16 | P1 |
| 4 | Project_Fact | DAILY_DASHBOARD_PROJECT | FACT_DD_TBS.dtsx | 9 | 901.8s | 915.9s | 1,070.0s | 1,070.0s | 2.25h | 0% | CV 0.14 | P1 |
| 5 | Project_Fact | DWH_GRADING_TBS | Fact.dtsx | 2 | 3,602.6s | 3,602.6s | N/A | 3,748.1s | 2.00h | 0% | CV 0.04 | P2 |
| 6 | Project_Fact | Controllable Profit | ControllableProfit\STG to DWH.dtsx | 2 | 3,359.8s | 3,359.8s | N/A | 3,675.1s | 1.87h | 0% | CV 0.09 | P2 |
| 7 | Sequence_Table | Sequence_Table | Seq_Staging_SIGAP.dtsx | 1 | 6,336.3s | 6,336.3s | N/A | 6,336.3s | 1.76h | 0% | Single sample | P1 |
| 8 | Project_Fact | DWH_LHM | Fact Rekap.dtsx | 6 | 921.2s | 732.3s | 1,708.8s | 1,708.8s | 1.54h | 0% | CV 0.54 | P2 |
| 9 | Project_Fact | SPARTA_PROJECT | FACT_SPARTA_FISIK_PREMI.dtsx | 5 | 968.6s | 842.1s | 1,571.1s | 1,571.1s | 1.35h | 0% | CV 0.43 | P2 |
| 10 | Sequence_Table | Sequence_Table | Seq_Staging_SPARTA_4T.dtsx | 5 | 961.6s | 957.7s | 1,109.8s | 1,109.8s | 1.34h | 0% | CV 0.11 | P2 |
| 11 | Project_Fact | JOURNAL_SPARTA | FACT_JOURNAL_PAYROLL.dtsx | 3 | 1,593.4s | 1,695.3s | N/A | 1,791.8s | 1.33h | 0% | CV 0.14 | P2 |
| 12 | Project_Fact | DWH_LKK_PROJECT_NEW | FACT_LKK.dtsx | 1 | 4,220.0s | 4,220.0s | N/A | 4,220.0s | 1.17h | 0% | Single sample | P1 |
| 13 | Project_Fact | DWH_PLASMA_GAPOKTAN | Fact.dtsx | 2 | 2,072.0s | 2,072.0s | N/A | 2,126.0s | 1.15h | 0% | CV 0.03 | P2 |
| 14 | Project_Fact | INVESTOR_RELATIONS_PROJECT | PS_AS.dtsx | 1 | 4,042.3s | 4,042.3s | N/A | 4,042.3s | 1.12h | 100% | Single sample; failed | P1 reliability |
| 15 | Sequence_Table | Sequence_Table | Seq_Staging_SPARTA.dtsx | 3 | 1,029.5s | 998.7s | N/A | 1,197.3s | 0.86h | 0% | CV 0.14 | P2 |

## 6. Top Performance Findings

### Finding 1 — `Seq_Staging_SIGAP` has a demonstrated, concentrated long-running branch

**Priority:** P1  
**Confidence:** CONFIRMED for elapsed-time concentration; POSSIBLE for causal mechanism  
**Affected Workload:** `Sequence_Table / Sequence_Table / Seq_Staging_SIGAP.dtsx / \\Package4`

**Observation:** One successful execution lasted 6,336.348 seconds. The `\\Package4` executable lasted 6,334.656 seconds, or approximately 99.97% of package elapsed time. Its nested `data_collection_transation_dtl` branch lasted 6,324.750 seconds.

**Evidence:** `03_runtime/executions.csv`, execution `1240550`; `03_runtime/executable_statistics.csv`, execution `1240550`, paths `\\Package4`, `\\Package4\\| data_collection_transation_dtl`, and `\\Package4\\| data_collection_transation_dtl\\SIGAP_data_collection_transation_dtl`; `03_runtime/slow_executables.csv` contains the same ranked paths.

**Bottleneck Location:** SSIS package/control-flow branch `\\Package4`, particularly the nested `SIGAP_data_collection_transation_dtl` executable.

**Technical Interpretation:** Elapsed time is concentrated in one branch rather than spread across the package. Executable timings are nested and overlapping, so they are evidence of location, not additive workload.

**Root Cause / Hypothesis:** The evidence proves the hot branch but not whether the delay is source access, destination write, SQL execution, data volume, waiting, or an SSIS task configuration.

**Recommendation:** Inspect the child task and its source/destination operations, then collect component phases and data statistics for a comparable rerun. Review SQL execution separately only after database-side evidence is captured.

**Expected Benefit:** High.  
**Implementation Effort:** Medium.  
**Change Risk:** Medium.

**Validation Method:** Baseline package duration and the `\\Package4`/child durations for at least five comparable runs. After the targeted change, compare median/P95 duration, child-task elapsed time, rows sent if available, and success rate. Confirm that functional row counts and outputs remain correct.

### Finding 2 — `AWL\Staging.dtsx` is the largest cumulative workload consumer

**Priority:** P1  
**Confidence:** CONFIRMED for cumulative impact; POSSIBLE for cause  
**Affected Workload:** `Project_Fact / AWL / Staging.dtsx`

**Observation:** 34 successful executions totaled 11,122.319 seconds, more than any other package key in the raw extract. Average duration was 327.1 seconds, median 276.1 seconds, P95 720.6 seconds, and maximum 859.2 seconds. The runtime CV was approximately 0.53.

**Evidence:** `03_runtime/executions.csv`, 34 execution IDs for `AWL / Staging.dtsx`; `03_runtime/package_runtime_summary.csv`, corresponding package summary row; `03_runtime/executable_statistics.csv`, including execution `1240317` where `\\Package\\API to STG\\Execute Process Task` ran 854.562 seconds.

**Bottleneck Location:** Package-level cumulative workload; the largest observed single path is `\\Package\\API to STG\\Execute Process Task` in execution `1240317`.

**Technical Interpretation:** High frequency plus moderate-to-high duration variability makes this the highest-value recurring workload to investigate. The executable evidence points to the API-to-staging process in the slowest observed run.

**Root Cause / Hypothesis:** The evidence supports an API/process-stage investigation but does not prove network, API, database, or SSIS implementation causality.

**Recommendation:** Profile the API-to-staging task across normal and slow runs, recording source response time, rows/bytes, staging write time, and task-level waits. Investigate repeated processing or scheduling overlap before changing package concurrency.

**Expected Benefit:** High.  
**Implementation Effort:** Medium.  
**Change Risk:** Medium.

**Validation Method:** Compare at least five before/after runs at comparable input volume. Track package median/P95, `API to STG` executable duration, rows/bytes processed, overlap with other executions, and failure rate.

### Finding 3 — Several packages are consistently multi-minute or multi-hour cumulative consumers

**Priority:** P1  
**Confidence:** CONFIRMED for runtime ranking; POSSIBLE for cause  
**Affected Workloads:** `premi dan lembur monitoring\DWH_STG to DWH_DM.dtsx`, `SPARTA_PROJECT\FACT_SPARTA_LHA_NEW.dtsx`, `DAILY_DASHBOARD_PROJECT\FACT_DD_TBS.dtsx`, and `DWH_GRADING_TBS\Fact.dtsx`.

**Observation:** The first three have five, five, and nine successful runs respectively, totaling 10,284.305, 10,133.694, and 8,116.303 seconds. `DWH_GRADING_TBS\Fact.dtsx` has two successful runs totaling 7,205.128 seconds, each lasting roughly 57–62 minutes.

**Evidence:** `03_runtime/executions.csv` and `03_runtime/package_runtime_summary.csv`; `03_runtime/executable_statistics.csv` identifies `\\Package` for the premi workload, `\\FACT_SPARTA_LHA_NEW` for SPARTA, `\\Package1` for `FACT_DD_TBS`, and `\\Package1\\FACT_AI_GRADING_PENERIMAAN_TBS` for `DWH_GRADING_TBS`.

**Bottleneck Location:** Package/control-flow branches identified above. Component-level location is not available.

**Technical Interpretation:** These workloads are meaningful optimization candidates because of elapsed time and cumulative impact, but the current evidence does not establish whether the dominant work is SSIS-side or database/source-side.

**Root Cause / Hypothesis:** The likely mechanism must be determined by task and component instrumentation; static indicators provide only prioritization context.

**Recommendation:** Prioritize task-level profiling in cumulative-runtime order after `Seq_Staging_SIGAP` and `AWL\Staging`. Capture source/destination timings, row counts, and SQL evidence before making design changes.

**Expected Benefit:** Medium to High.  
**Implementation Effort:** Medium to High.  
**Change Risk:** Medium.

**Validation Method:** Establish package and hot-executable baselines, then retest with equivalent data. Compare P50/P95, cumulative runtime per schedule window, task durations, outputs, and success rate.

### Finding 4 — Runtime failures are recurring connection and validation reliability issues

**Priority:** P1 reliability  
**Confidence:** CONFIRMED  
**Affected Workloads:** `DWH_GRADING_TBS\Staging.dtsx`, `Sequence_Table\Seq_Staging_WB.dtsx`, `Sequence_Table\Seq_Staging_NON_SAP.dtsx`, `INVESTOR_RELATIONS_PROJECT\PS_AS.dtsx`, and related packages.

**Observation:** 11 of 500 raw executions failed or ended unexpectedly. `DWH_GRADING_TBS\Staging.dtsx` failed in executions `1240750`, `1240636`, and `1240522`; `Seq_Staging_WB.dtsx` failed or ended unexpectedly in `1240719`, `1240716`, and `1240339`; `PS_AS.dtsx` failed in `1240698`.

**Evidence:** `03_runtime/executions.csv`; `04_messages/event_messages.csv` and `04_messages/operation_messages.csv`. Execution `1240750` records a PostgreSQL connection timeout; `1240719` and `1240716` record SQL login/connection timeout and validation errors; `1240713` and `1240720` record missing connection-manager errors; `1240698` records a session in the kill state.

**Bottleneck Location:** Reliability layer: connection acquisition/validation and external dependency availability. This is not classified as a proven performance bottleneck.

**Technical Interpretation:** The error messages directly explain several failures. Retries or repeated schedules can also increase operational workload, but retry behavior is not present in the evidence.

**Root Cause / Hypothesis:** Proven immediate conditions are connection timeout, missing connection-manager references, and killed-session failure. The underlying infrastructure or deployment cause is not proven.

**Recommendation:** Remediate connection-manager/deployment consistency and dependency availability. Review the affected package configurations and validation behavior; do not broaden `MaximumErrorCount` as a performance fix.

**Expected Benefit:** High reliability benefit.  
**Implementation Effort:** Medium.  
**Change Risk:** Medium.

**Validation Method:** Re-run each affected package under the same dependency conditions. Require zero connection/validation errors in the test set, successful completion, and no regression in duration or output correctness.

### Finding 5 — Static complexity correlates with some runtime hotspots but is not causal proof

**Priority:** P2/P3 investigation  
**Confidence:** POSSIBLE  
**Affected Workloads:** `SPARTA_PROJECT\FACT_SPARTA_LHA_NEW.dtsx`, `DAILY_DASHBOARD_PROJECT\FACT_DD_TBS.dtsx`, and `DWH_LKK_PROJECT_NEW\FACT_LKK.dtsx`.

**Observation:** The three workloads have substantial runtime impact. Their static summaries contain Sort, Lookup, and Merge indicators: SPARTA has 21 executable nodes, 73 Data Flow components, 67 paths; DAILY has 12 nodes, 55 components, 50 paths; FACT_LKK has 15 nodes, 75 components, 63 paths.

**Evidence:** `01_static_packages/package_static_summary.csv`, exact package rows; `03_runtime/executions.csv` and `03_runtime/executable_statistics.csv`, including execution IDs `1240383`, `1240531`, `1240381`, `1240683`, and `1240598`.

**Technical Interpretation:** Complexity and blocking/join-like indicators make these packages appropriate inspection targets. However, `execution_component_phases.csv` and `execution_data_statistics.csv` are empty, so no component can be tied to elapsed time or throughput.

**Recommendation:** Inspect the affected Data Flows and capture component-level runtime evidence before changing Sort, Lookup, or Merge design. Preserve required ordering and functional semantics.

**Expected Benefit:** Medium.  
**Implementation Effort:** High.  
**Change Risk:** Medium to High.

**Validation Method:** Compare component phase duration, rows sent, package duration, and output reconciliation before and after any design change.

## 7. Package & Executable Hotspot Analysis

The executable evidence confirms elapsed-time concentration for several package-level hotspots:

| Workload | Execution | Hot executable path | Duration | Approx. package contribution |
|---|---:|---|---:|---:|
| `Seq_Staging_SIGAP.dtsx` | 1240550 | `\\Package4` | 6,334.656s | 99.97% |
| `FACT_LKK.dtsx` | 1240598 | `\\FACT_LKK` | 4,207.906s | 99.71% |
| `PS_AS.dtsx` | 1240698 | `\\PS_AS` | 4,030.593s | 99.71%; failed run |
| `DWH_GRADING_TBS\Fact.dtsx` | 1240384 | `\\Package1` | 3,744.000s | 99.89% |
| `ControllableProfit\STG to DWH.dtsx` | 1240394 | `\\STG to DWH` | 3,621.500s | 98.52% |
| `premi dan lembur monitoring` | 1240520 | `\\Package` | 2,691.485s | 99.28% |
| `SPARTA_PROJECT\FACT_SPARTA_LHA_NEW.dtsx` | 1240383 | `\\FACT_SPARTA_LHA_NEW` | 2,401.984s | 95.87% |
| `DWH_LHM\Fact Rekap.dtsx` | 1240776 | `\\Fact Rekap` | 1,705.921s | 99.95% |

These contributions use the largest observed executable row divided by the corresponding package duration. Nested executable rows overlap, so they are not additive. They identify where package elapsed time is concentrated, not the underlying resource consumed.

For `AWL\Staging.dtsx`, execution `1240317` is the clearest slow-run trace: `\\Package\\API to STG\\Execute Process Task` lasted 854.562 seconds against a package duration of 859.241 seconds. Other AWL runs show the same branch as the dominant path, but component-level evidence is unavailable.

## 8. Data Flow / Component Analysis

Component-level bottlenecks are **not identifiable conclusively** from the current evidence. Both `03_runtime/execution_component_phases.csv` and `03_runtime/execution_data_statistics.csv` contain zero data rows.

The messages do provide design/runtime warnings, including 3,510 unused-output-column warnings across 86 execution IDs, 79 external-column-out-of-synchronization warnings across 19 execution IDs, 21 duplicate-reference-key warnings across 10 execution IDs, and two empty-foreach warnings. These are investigation signals, not measured component bottlenecks. No rows/sec calculation is defensible because row statistics are absent.

## 9. Static-to-Runtime Correlation

Static package summary coverage is strong for extracted ISPACs: 781/781 packages parsed successfully. Across the static set, the indicators occur in 178 packages with Sort, 93 with Aggregate, 108 with Lookup, 174 with Merge, and 2 with Script.

| Correlation class | Evidence | Assessment |
|---|---|---|
| Correlated runtime/design target | SPARTA `FACT_SPARTA_LHA_NEW`: 5 runs, 2,026.7s average; 21 nodes, 73 components, 67 paths; Sort/Lookup/Merge indicators | POSSIBLE investigation target; no component timings |
| Correlated runtime/design target | DAILY `FACT_DD_TBS`: 9 runs, 901.8s average; 55 components, 50 paths; Sort/Lookup/Merge indicators | POSSIBLE investigation target; no component timings |
| Correlated runtime/design target | `FACT_LKK`: 4,220.0s single run; 75 components, 63 paths; Sort/Lookup/Merge indicators | POSSIBLE investigation target; one runtime sample |
| Runtime hotspot without these indicators | AWL `Staging.dtsx`: 34 runs, 11,122.3s cumulative; no Sort/Aggregate/Lookup/Merge/Script indicator | Runtime impact is confirmed; static anti-pattern explanation is not supported |
| Complexity-only target | `Seq_Staging_SPARTA.dtsx` and `Seq_Staging_SAP.dtsx` have 253 and 309 executable nodes respectively | INFORMATIONAL unless runtime/component evidence shows impact |
| Warning correlation | Duplicate Lookup reference keys occur in SPARTA-related executions, including `1240760`, `1240758`, `1240754`, and `1240751` | POSSIBLE correctness/performance investigation; no measured cost |

The evidence does not justify removing Sort, Aggregate, Merge, Script, or changing Lookup cache mode solely because an indicator exists.

## 10. Reliability & Error Findings

Reliability issues are separate from performance findings.

- `DWH_GRADING_TBS\Staging.dtsx`: three failures (`1240750`, `1240636`, `1240522`). The first two include PostgreSQL connection timeout messages for `172.30.203.167:5432`, followed by validation failure.
- `Sequence_Table\Seq_Staging_WB.dtsx`: failures/unexpected terminations `1240719`, `1240716`, and `1240339`. The two detailed runs include SQL login timeout, connection acquisition, validation, and maximum-error-count messages.
- `Sequence_Table\Seq_Staging_NON_SAP.dtsx`: unexpected termination `1240713` and failure `1240720`; messages report missing connection references.
- `INVESTOR_RELATIONS_PROJECT\PS_AS.dtsx`: failed execution `1240698` lasted 4,042.260 seconds and reported that the session was in the kill state. This is both a long failed run and a reliability issue, but the evidence does not establish why the session was killed.
- `MONITORING_TICKET_WB\STAGING.dtsx`: ended unexpectedly in execution `1240715`.
- Duplicate reference-key warnings occur in Full Cache mode messages for Lookup components, but the current evidence does not show their elapsed-time impact.
- Repeated unused-output and external-column synchronization warnings indicate technical debt and potential low-risk cleanup candidates, but they are not independently proven bottlenecks.

## 11. Database-Side Findings

Database-side performance is outside the conclusively assessable scope of the current evidence set.

Query Store collection was disabled (`CollectQueryStore=False`), and no Query Store evidence is present. Therefore this report does not infer CPU pressure, memory pressure, disk latency, blocking, execution-plan problems, missing indexes, SQL duration, or database wait causes. The connection timeout and killed-session messages establish runtime failure conditions, not database performance root causes.

## 12. Quick Wins

No code-level quick win is conclusively proven from the current evidence. The following operational actions have clear scope and low-to-medium implementation risk, but must be validated:

| Priority | Recommendation | Affected Workload | Evidence | Expected Impact | Effort | Risk | Validation |
|---|---|---|---|---|---|---|---|
| P1 | Repair missing connection-manager/deployment references and validate dependency availability | `Seq_Staging_WB`, `Seq_Staging_NON_SAP`, `Seq_Staging_SAP_SALDO_TREASURY` | Executions `1240719`, `1240716`, `1240713`, `1240720`, `1240739`; event/operation messages | High reliability impact | Medium | Medium | Repeat affected executions with zero validation/acquire-connection errors |
| P2 | Remove demonstrably unused output columns after functional review | Packages represented in 3,510 unused-output warnings | `04_messages/event_messages.csv`, 86 execution IDs | Low to Medium potential Data Flow overhead reduction | Low to Medium | Low | Compare component/package duration and output-column correctness |
| P2 | Refresh external metadata where source schema is confirmed changed | Packages represented in 79 synchronization warnings | `04_messages/event_messages.csv`, 19 execution IDs | Reliability/maintenance improvement; performance unproven | Low | Low | Validate package execution and source-column mappings |

## 13. Strategic Improvements

### Evidence-backed strategic improvements

- Add a repeatable performance-observation workflow for the high-cumulative packages: capture package duration, executable timing, rows/bytes, source/destination timing, and execution overlap for each benchmark run.
- Increase the execution sample beyond the current 500-row cap when making workload-level decisions. The one-day sample contains many single-observation packages and cannot establish long-term behavior.
- Separate reliability remediation from performance tuning so connection failures and validation errors do not contaminate duration comparisons.

### Require further investigation before implementation

- Investigate decomposition or incremental processing for `Seq_Staging_SIGAP`, `AWL\Staging`, and other multi-hour workloads only after task/component and data-volume evidence identifies the work being repeated.
- Investigate SQL pushdown or database-side tuning only after Query Store or equivalent SQL evidence links specific queries to SSIS tasks.
- Review scheduling overlap and concurrency only when schedule history and overlapping execution timelines are available. Do not increase concurrency from this evidence alone.

## 14. Performance Tuning Roadmap

| Priority | Finding | Workload | Bottleneck Layer | Evidence | Impact | Confidence | Effort | Risk | Action | Validation |
|---|---|---|---|---|---|---|---|---|---|---|
| P0 | None | — | — | No severe issue requiring P0 is proven | — | — | — | — | — | — |
| P1 | Concentrated 105.6-minute branch | `Seq_Staging_SIGAP` | SSIS PACKAGE / CONTROL FLOW; mechanism unknown | Execution `1240550`; `\\Package4` 6,334.656s | High | Confirmed location | Medium | Medium | Profile child task and source/destination work | Reduce hot-branch P95/median without output or reliability regression |
| P1 | Largest cumulative consumer | `AWL\Staging` | SSIS PACKAGE / CONTROL FLOW; API/process target | 34 runs; 11,122.319s; execution `1240317` hot API path | High | Confirmed impact | Medium | Medium | Profile API-to-STG process and repeated work | Reduce package P95 and API-task duration at comparable volume |
| P1 | Recurring failures | `DWH_GRADING_TBS`, `Seq_Staging_WB`, `Seq_Staging_NON_SAP` | RELIABILITY / OPERATIONAL | 11/500 non-success; connection and validation messages | High reliability | Confirmed | Medium | Medium | Repair connection/deployment conditions | Zero corresponding failure messages in retest |
| P1 | Multi-hour packages | premi, SPARTA, DAILY, DWH_GRADING | SSIS PACKAGE / CONTROL FLOW; source/database cause unknown | Raw executions and executable statistics | High | Confirmed runtime impact | Medium/High | Medium | Instrument in cumulative order | Improve duration distribution without increased failure rate |
| P2 | Complex Data Flow candidates | SPARTA, DAILY, FACT_LKK | SSIS DATA FLOW / COMPONENT, unproven | Static summary indicators and runtime ranking | Medium | Possible | High | Medium/High | Capture component phases and rows before redesign | Component duration/throughput and package duration improve |
| P2 | High runtime variability | `CHECK_QUERY_DATA`, AWL child packages | UNKNOWN / INSUFFICIENT EVIDENCE | Raw medians/P95/max and CV | Medium | Confirmed variability; cause unknown | Medium | Low/Medium | Correlate duration with input volume and overlap | Lower variance at comparable workload |
| P3 | Warning cleanup | 86 executions with unused outputs; 19 with out-of-sync metadata | SSIS DATA FLOW / OPERATIONAL | Event messages | Low/Medium | Informational/Possible | Low/Medium | Low | Review and clean only safe, unused metadata | No output regression and measurable timing/maintenance improvement |

### P0 — Immediate

No P0 finding is supported.

### P1 — High Priority

Investigate `Seq_Staging_SIGAP`, `AWL\Staging`, the multi-hour cumulative packages, and recurring connection/validation failures. These priorities are driven by measured elapsed time, cumulative workload, frequency, or reliability impact.

### P2 — Medium Priority

Instrument complex Data Flows and unstable packages, then investigate static indicators only where runtime evidence supports the work.

### P3 — Optimization / Investigation

Clean low-risk warnings after functional review and expand observability. Do not promote these warnings to bottlenecks without before/after measurements.

## 15. Validation & Benchmark Plan

For every P1 performance change:

1. **Baseline:** Capture at least five comparable executions where possible. Record package start/end/duration, success status, hot executable duration, input/output volume, rows sent, and concurrent executions. For single-sample `Seq_Staging_SIGAP`, first collect repeatable baseline runs.
2. **Change:** Make one targeted change at a time: task/source/destination investigation for `Seq_Staging_SIGAP`, API-to-staging investigation for `AWL`, and dependency/connection repair for reliability packages.
3. **Re-test:** Use comparable data range, schedule conditions, environment, and package parameters. Keep failed executions separate from successful-duration statistics.
4. **Success criteria:** P95 and median package duration decrease for repeated workloads; hot executable duration decreases; failure rate does not increase; output row counts and reconciliation remain correct. For reliability work, the corresponding connection/validation errors must disappear.

Do not use a target percentage because no SLA or defensible improvement estimate is present in the evidence.

## 16. Evidence Gaps

### Empty component phases and data statistics

1. **Missing:** `execution_component_phases.csv` and `execution_data_statistics.csv` have zero rows.
2. **Prevents:** Direct identification of Data Flow component duration, rows sent, throughput, and component-level causal ranking.
3. **Usability:** Package and executable elapsed-time findings remain usable and strongly locate several hot branches.
4. **Additional evidence:** Collect component-phase and data-statistics logging for representative executions of the P1 packages.

### No Query Store/database evidence

1. **Missing:** Query Store was disabled and no database-side evidence exists.
2. **Prevents:** SQL query, plan, reads, waits, blocking, and database-resource conclusions.
3. **Usability:** SSIS package/control-flow and reliability findings remain usable; database-side cause remains indeterminate.
4. **Additional evidence:** Collect Query Store or an equivalent, defensibly correlated SQL trace for the selected package executions.

### Capped and mismatched runtime populations

1. **Missing:** Complete history beyond the 500 raw execution cap and a reconciled definition for the 5,128 executions in the 200 summary rows.
2. **Prevents:** Complete workload frequency, long-term trend, schedule-window, and exact summary/raw reconciliation.
3. **Usability:** The raw sample supports ranking and concrete execution findings, with reduced confidence for low-sample packages.
4. **Additional evidence:** Collect a documented observation window with uncapped or paginated raw executions and matching summary population.

### Static/runtime package alignment

1. **Missing:** Exact static evidence for 28 of 183 runtime package keys, plus empty environment inventories.
2. **Prevents:** Static-to-runtime correlation and environment-parameter analysis for those workloads.
3. **Usability:** Correlations for exact matched keys remain usable; unmatched packages must be treated as unknown.
4. **Additional evidence:** Obtain the deployed ISPAC/package artifacts and environment values corresponding to the runtime keys.

### Message truncation

1. **Missing:** Full event and operation message history; each file contains 20,000 rows.
2. **Prevents:** Complete recurring-warning/error frequency and all failure-pattern analysis.
3. **Usability:** Direct examples and recurring patterns in the captured rows remain usable.
4. **Additional evidence:** Collect messages with pagination or a documented larger limit for the same execution population.

## 17. Final Assessment Conclusion

1. **Which packages are actually slow?** `Seq_Staging_SIGAP.dtsx` is the longest observed run at 105.6 minutes. `FACT_LKK`, `PS_AS`, `DWH_GRADING_TBS\Fact`, and `ControllableProfit\STG to DWH` are also multi-hour/single-run or multi-run packages. `AWL\Staging` is slower in cumulative operational impact than any other raw package key.
2. **Which workloads consume the most cumulative runtime?** `AWL\Staging.dtsx` (11,122.319s), premi (10,284.305s), SPARTA LHA (10,133.694s), DAILY TBS (8,116.303s), and DWH Grading Fact (7,205.128s).
3. **Which packages are unstable or failure-prone?** `Seq_Staging_WB` (75% non-success), `DWH_GRADING_TBS\Staging` (60%), `INVESTOR_RELATIONS_PROJECT\PL_BS` (50%), and `MONITORING_TICKET_WB\STAGING` (33.3%) in the raw sample. `CHECK_QUERY_DATA` and AWL child packages show high runtime spread without failures.
4. **Which executables account for most observed package runtime?** `\\Package4` in `Seq_Staging_SIGAP` accounts for approximately 99.97% of execution `1240550`; the top package-level paths for FACT_LKK, PS_AS, DWH Grading Fact, ControllableProfit, premi, SPARTA, and DWH_LHM similarly account for approximately 95.87%–99.95% of their selected executions. Nested timings overlap.
5. **Are component-level bottlenecks identifiable?** No. Component phases and data statistics are empty.
6. **Which static design risks correlate with runtime hotspots?** SPARTA LHA, DAILY TBS, and FACT_LKK combine runtime impact with Sort/Lookup/Merge indicators and substantial Data Flow complexity. These are POSSIBLE investigation targets, not confirmed causes.
7. **Which findings are CONFIRMED?** Runtime duration rankings, cumulative impact, elapsed-time concentration in selected executable paths, and the observed reliability failures/messages.
8. **Which findings remain hypotheses?** The specific source, SQL, component, cache, buffer, concurrency, or database mechanism causing the long runtimes; static indicators are hypotheses only.
9. **Is the problem SSIS-side, database-side, or indeterminate?** The evidence confirms SSIS package/control-flow locations and operational reliability failures, but the underlying resource layer is indeterminate. Database-side performance cannot be conclusively assessed.
10. **What should be tuned or investigated first?** Profile `Seq_Staging_SIGAP\Package4`, then `AWL\Staging` / `API to STG`, then the other cumulative multi-hour packages. In parallel, repair recurring connection and validation failures.
11. **How should improvement be measured?** Use comparable before/after executions and compare median/P95 package duration, hot executable duration, cumulative schedule-window runtime, rows/volume where collected, success/failure rate, and output correctness.

**Health Score: Not Scorable From Available Evidence.** A reproducible numerical score cannot be constructed because the runtime population is capped/mismatched and component/database evidence is absent.
