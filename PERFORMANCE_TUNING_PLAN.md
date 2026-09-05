# SSIS Performance Tuning Implementation Plan

## 1. Tuning Objective

Reduce demonstrated SSIS elapsed-time and cumulative-runtime exposure while preserving functional correctness, and eliminate recurring connection/validation failures that contaminate workload reliability measurements.

The plan is deliberately evidence-led:

- First establish a reconciled baseline because the raw execution extract is capped at 500 while the package summary represents 5,128 executions.
- Profile the two clearest runtime targets: `Sequence_Table\Sequence_Table\Seq_Staging_SIGAP.dtsx` and `Project_Fact\AWL\Staging.dtsx`.
- Remediate explicitly evidenced connection and validation failures in a controlled test.
- Defer component redesign, SSIS configuration changes, and database tuning until the missing runtime/component/database evidence exists.

No percentage improvement target is assumed. Acceptance is based on comparable before/after measurements, failure behavior, and output correctness.

## 2. Assessment Findings Used

| Finding | Priority | Confidence | Action Type | Affected Workload |
|---|---|---|---|---|
| Elapsed time is concentrated in `\\Package4` | P1 | CONFIRMED for location; mechanism unknown | VALIDATE FIRST | `Seq_Staging_SIGAP.dtsx`, execution `1240550` |
| Largest raw cumulative runtime consumer | P1 | CONFIRMED for impact; cause unknown | VALIDATE FIRST | `AWL\Staging.dtsx` |
| Recurring connection and validation failures | P1 | CONFIRMED reliability issue | TUNE NOW, controlled test only | `DWH_GRADING_TBS\Staging`, `Seq_Staging_WB`, `Seq_Staging_NON_SAP` |
| Multiple multi-hour cumulative workloads | P1/P2 | CONFIRMED runtime impact; cause unknown | INVESTIGATE | `premi`, SPARTA LHA, DAILY TBS, DWH Grading Fact |
| Static complexity and Sort/Lookup/Merge indicators overlap with some hot packages | P2/P3 | POSSIBLE | VALIDATE FIRST | SPARTA LHA, DAILY TBS, FACT_LKK |
| High runtime variability | P2 | CONFIRMED variability; cause unknown | INVESTIGATE | `CHECK_QUERY_DATA`, AWL child packages, selected workloads |
| Broader summary reports `premi` 22 non-successes in 67 executions | P1 validation | POSSIBLE until populations reconcile | INVESTIGATE | `premi dan lembur monitoring` |

## 3. Baseline Performance

### Available baseline

| Workload | Raw baseline | Executable baseline | Reliability baseline |
|---|---|---|---|
| `Seq_Staging_SIGAP.dtsx` | 1 run, 6,336.348s | `\\Package4`: 6,334.656s; nested `data_collection_transation_dtl`: 6,324.750s | 1/1 succeeded |
| `AWL\Staging.dtsx` | 34 runs; average 327.1s; median 276.1s; P95 720.6s; max 859.2s; cumulative 11,122.319s | Execution `1240317`: `\\Package\\API to STG\\Execute Process Task`: 854.562s | 34/34 succeeded |
| `DWH_GRADING_TBS\Staging.dtsx` | 5 runs; 3 failed; average 51.0s | Component evidence unavailable | 40% success |
| `Seq_Staging_WB.dtsx` | 4 runs; 3 non-success; average 48.8s | Component evidence unavailable | 25% success |
| `premi\DWH_STG to DWH_DM.dtsx` | 5 raw successes; average 2,056.9s; cumulative 10,284.305s | Selected `\\Package`: up to 2,691.485s | Raw sample 5/5 success; summary reports 22 non-successes in 67 runs, unreconciled |

### Baselines that are unavailable

- Component phase durations and rows sent: both evidence files are empty.
- SQL duration, logical reads, plans, waits, blocking, and resource pressure: Query Store was not collected.
- Complete historical P95 and trend: raw executions are capped at 500 and many package samples are small.
- Reliable cross-population frequency/failure totals: package summary and raw execution populations do not reconcile.

Where a single-run baseline is insufficient, the first step is repeatable baseline establishment, not production tuning.

## 4. Recommended Execution Order

1. Reconcile the raw and package-summary populations and capture a documented observation window.
2. Repair and retest the explicitly evidenced connection/deployment/validation failures.
3. Establish repeatable baseline runs for `Seq_Staging_SIGAP` and `AWL\Staging`, including hot executable timing and input volume.
4. Capture component/data statistics and, where required, correlated SQL evidence.
5. Validate one performance hypothesis at a time in a non-production or controlled execution.
6. Benchmark the isolated change against comparable data and parameters.
7. Accept only if the selected performance metric improves without reliability or correctness regression; otherwise reject or roll back.
8. Move to the next workload in cumulative-impact order.

Dependencies are intentional: population reconciliation and reliability remediation must precede trustworthy workload comparisons; instrumentation must precede design changes.

## 5. Wave 0 — Validation & Measurement

- **SSIS-TUNE-001:** Reconcile raw executions and package summary, especially `premi`.
- **SSIS-TUNE-002:** Establish repeatable baseline and dependency timing for `Seq_Staging_SIGAP`.
- **SSIS-TUNE-003:** Establish repeatable baseline and API/staging timing for `AWL\Staging`.
- **SSIS-TUNE-004:** Capture component-phase, data-statistics, and selectively correlated SQL evidence for P1 workloads.
- **SSIS-TUNE-005:** Characterize runtime variability against input volume, time window, and overlap.

## 6. Wave 1 — High-Confidence Tuning

- **SSIS-TUNE-006:** Repair the known connection acquisition, missing connection-manager, timeout, and validation conditions in a controlled test. This is reliability remediation, not a claim that a specific SSIS configuration value should change.

No direct performance design change qualifies for Wave 1 yet. The two clearest performance findings identify location and impact, but not a proven mechanism.

## 7. Wave 2 — Secondary Optimization

- **SSIS-TUNE-007:** Inspect the `premi`, SPARTA LHA, DAILY TBS, and DWH Grading Fact package branches in cumulative-runtime order after baseline instrumentation.
- **SSIS-TUNE-008:** Validate the possible static/runtime correlations in SPARTA LHA, DAILY TBS, and FACT_LKK. Do not remove or reconfigure Sort, Lookup, Merge, or Aggregate solely from static indicators.
- **SSIS-TUNE-009:** Investigate repeated unused-output and external-metadata warnings after functional review. Cleanup is not presumed to improve runtime.

## 8. Wave 3 — Strategic Improvement

- Evaluate incremental processing, package decomposition, or scheduling redesign only if profiling shows repeated work, unacceptable serialized branches, or overlap-driven variability.
- Evaluate SQL pushdown or database-side changes only after correlated SQL evidence identifies a specific source query or database operation.
- Extend runtime observability so future assessments include component phases, rows sent, comparable execution populations, and uncapped/paginated evidence.

These are planning candidates, not approved production changes.

## 9. Detailed Tuning Actions

### SSIS-TUNE-001 — Reconcile runtime populations

**Priority:** P1  
**Action Type:** INVESTIGATE  
**Finding:** Raw execution evidence and package summary represent different populations.  
**Confidence:** POSSIBLE for the broader `premi` failure exposure; CONFIRMED that the populations differ.  
**Scope:** `assessments/EVSET-001/03_runtime/executions.csv`; `package_runtime_summary.csv`; `premi dan lembur monitoring / DWH_STG to DWH_DM.dtsx`.

**Evidence:** Raw file contains 500 executions. Summary contains 200 package rows and 5,128 summarized executions. Summary row for `premi` reports 67 executions, 45 succeeded, 22 failed/unexpected, average 1,792.15s; raw contains five successful executions for the same key.

**Current Observation:** Frequency and failure conclusions change materially depending on which population is used.

**Technical Hypothesis / Root Cause:** Different query limits, windows, or aggregation populations; the collector configuration and files do not prove which difference applies.

**Proposed Action:** Obtain a matching, documented, paginated raw execution extract and summary derived from the same execution IDs/window. Do not tune the package based on the unreconciled rate.

**Why This Action:** It is a prerequisite for trustworthy prioritization and before/after comparison.

**Expected Effect:** Very High decision-quality benefit.  
**Implementation Effort:** Medium.  
**Change Risk:** Low.

**Dependencies:** None; precedes all workload-level comparisons.  
**Baseline Metrics:** 500 raw rows; 5,128 summary executions; `premi` 5 raw vs 67 summary executions.  
**Validation Test:** Re-run collection with identical filters and documented time bounds; join summary and raw data by execution ID.  
**Success Criteria:** Counts, status totals, package keys, and time window reconcile or the population difference is explicitly explained.  
**Regression Guardrails:** No loss of execution IDs, statuses, or duration values.  
**Rollback Criteria:** Revert to the last known-good collection query/process if records are lost, duplicated, or status totals cannot be audited.

### SSIS-TUNE-002 — Profile `Seq_Staging_SIGAP\\Package4`

**Priority:** P1  
**Action Type:** VALIDATE FIRST  
**Finding:** One branch accounts for nearly all observed package elapsed time.  
**Confidence:** CONFIRMED for elapsed-time location; POSSIBLE for cause.  
**Scope:** `Sequence_Table / Sequence_Table / Seq_Staging_SIGAP.dtsx / \\Package4 / data_collection_transation_dtl`.

**Evidence:** `executions.csv`, execution `1240550`, duration 6,336.348s; `executable_statistics.csv`, `\\Package4` 6,334.656s and nested branch 6,324.750s; `slow_executables.csv` contains the same paths.

**Current Observation:** One successful run lasted 105.6 minutes; only one raw sample exists.

**Technical Hypothesis / Root Cause:** The hot child task may be waiting on source/API, destination, SQL, or data-volume work. Root cause is not proven.

**Proposed Action:** Capture a repeatable baseline and instrument the child task’s source, transform, destination, dependency, and SQL timings. Collect component phases and rows sent if possible.

**Why This Action:** The runtime location is precise, but changing design without mechanism evidence risks functional or operational regression.

**Expected Effect:** High diagnostic and potential performance benefit.  
**Implementation Effort:** Medium.  
**Change Risk:** Low.

**Dependencies:** SSIS-TUNE-001; controlled test data and dependency availability.  
**Baseline Metrics:** Package duration; `\\Package4` duration; nested branch duration; input/output volume; status.  
**Validation Test:** Run at least five comparable executions, then isolate one primary change only after the delay mechanism is observed.  
**Success Criteria:** A repeatable reduction in package and hot-branch median/P95 without output or status regression.  
**Regression Guardrails:** Output reconciliation, row counts, data freshness, and success rate must not worsen.  
**Rollback Criteria:** Restore the prior package version if output differs, failures increase, or the change does not improve the selected metric.

### SSIS-TUNE-003 — Profile `AWL\\Staging` API-to-staging work

**Priority:** P1  
**Action Type:** VALIDATE FIRST  
**Finding:** `AWL\Staging.dtsx` is the largest raw cumulative runtime consumer.  
**Confidence:** CONFIRMED for cumulative impact; POSSIBLE for cause.  
**Scope:** `Project_Fact / AWL / Staging.dtsx / \\Package\\API to STG\\Execute Process Task`.

**Evidence:** 34 successful raw executions, cumulative 11,122.319s, average 327.1s, P95 720.6s, maximum 859.2s. Execution `1240317` shows the API process path at 854.562s.

**Current Observation:** Recurring execution and high spread create the largest raw cumulative exposure.

**Technical Hypothesis / Root Cause:** API response time, process behavior, staging write time, input volume, or overlap may explain variance; none is proven.

**Proposed Action:** Measure API response/process time, staging write time, data volume, schedule overlap, and task duration across normal and slow runs. Investigate repeated processing before considering design changes.

**Why This Action:** It targets the largest repeated workload and isolates the observed hot path.

**Expected Effect:** High.  
**Implementation Effort:** Medium.  
**Change Risk:** Low.

**Dependencies:** SSIS-TUNE-001; representative API and staging dependencies.  
**Baseline Metrics:** 34-run average/median/P95/max; cumulative runtime; API-task duration; input/output volume; overlap; success rate.  
**Validation Test:** Compare at least five comparable normal/slow runs before selecting one change.  
**Success Criteria:** Lower comparable package P95 and/or API-task duration with no failure or output regression.  
**Regression Guardrails:** API completeness, staging row counts, downstream correctness, and success rate.  
**Rollback Criteria:** Restore prior implementation when data completeness fails, failures rise, or duration worsens materially.

### SSIS-TUNE-004 — Add missing runtime and database observability

**Priority:** P1  
**Action Type:** INVESTIGATE  
**Finding:** Component phases and data statistics are empty; Query Store was not collected.  
**Confidence:** CONFIRMED evidence gap.  
**Scope:** P1 packages selected by SSIS-TUNE-002 and SSIS-TUNE-003, then premi/SPARTA/DAILY/DWH Grading.

**Evidence:** `execution_component_phases.csv` and `execution_data_statistics.csv` contain zero rows; collector environment reports `CollectQueryStore=False` and no Query Store evidence exists.

**Current Observation:** Package/executable location is available, but component throughput and database contribution are indeterminate.

**Technical Hypothesis / Root Cause:** Collection settings/logging scope did not produce the required granular evidence; specific resource cause is unknown.

**Proposed Action:** Enable or collect component phases and rows sent for controlled benchmark runs. Capture Query Store or equivalent correlated SQL evidence only for the selected tasks.

**Why This Action:** It prevents speculative changes to components, SQL, buffers, or concurrency.

**Expected Effect:** Very High diagnostic benefit; direct runtime benefit is not assumed.  
**Implementation Effort:** Medium.  
**Change Risk:** Low/Medium.

**Dependencies:** Selected execution IDs and controlled test window.  
**Baseline Metrics:** Existing package/executable durations and statuses; new component duration/rows/SQL metrics.  
**Validation Test:** Execute selected packages with the additional observation enabled and verify records are populated and correlated by execution ID.  
**Success Criteria:** Component and SQL evidence is complete enough to identify or exclude a target mechanism.  
**Regression Guardrails:** Logging must not materially disrupt package execution or alter outputs.  
**Rollback Criteria:** Disable/revert added diagnostics if they cause unacceptable execution overhead or operational risk.

### SSIS-TUNE-005 — Validate variability drivers

**Priority:** P2  
**Action Type:** INVESTIGATE  
**Finding:** Several repeated packages show substantial runtime spread.  
**Confidence:** CONFIRMED variability; POSSIBLE cause.  
**Scope:** `DWH_SMALLER_FACT\CHECK_QUERY_DATA.dtsx`, AWL child packages, and selected high-volume workloads.

**Evidence:** `CHECK_QUERY_DATA`: 24 runs, median 5.4s, P95 180.9s, max 186.5s; `AWL\Fact.dtsx`: 34 runs, CV approximately 1.54; `AWL\AWL_Warning.dtsx`: 34 runs, CV approximately 1.46.

**Current Observation:** Duration varies widely, but volume, overlap, and failure/retry relationships are not available.

**Technical Hypothesis / Root Cause:** Data volume, execution window, overlapping work, external dependencies, or retries may drive the spread.

**Proposed Action:** Correlate each run with input volume, start time, concurrent executions, executable paths, and dependency status.

**Why This Action:** It avoids incorrectly attributing variance to package design.

**Expected Effect:** Medium diagnostic benefit.  
**Implementation Effort:** Medium.  
**Change Risk:** Low.

**Dependencies:** SSIS-TUNE-001 and observability from SSIS-TUNE-004.  
**Baseline Metrics:** Median/P95/max, CV, input volume, overlap, and statuses.  
**Validation Test:** Analyze a sufficiently populated, reconciled execution window.  
**Success Criteria:** A defensible variance driver is identified or ruled out.  
**Regression Guardrails:** No production design change until causality is supported.  
**Rollback Criteria:** Not applicable to analysis; discard the hypothesis if correlations are not reproducible.

### SSIS-TUNE-006 — Repair connection and validation failures

**Priority:** P1  
**Action Type:** TUNE NOW, controlled reliability remediation  
**Finding:** Repeated connection acquisition, timeout, missing connection-manager, and validation failures are causing non-success executions.  
**Confidence:** CONFIRMED reliability issue.  
**Scope:** `DWH_GRADING_TBS\Staging.dtsx`, `Sequence_Table\Seq_Staging_WB.dtsx`, `Sequence_Table\Seq_Staging_NON_SAP.dtsx`, and related affected paths.

**Evidence:** 11/500 raw executions failed or ended unexpectedly. IDs include `1240750`, `1240636`, `1240522`, `1240719`, `1240716`, `1240339`, `1240713`, and `1240720`. Messages report PostgreSQL timeout, SQL login timeout, missing connection references, connection acquisition failure, and validation failure.

**Current Observation:** `DWH_GRADING_TBS\Staging` has 3/5 non-successes; `Seq_Staging_WB` has 3/4; `Seq_Staging_NON_SAP` has 1/4.

**Technical Hypothesis / Root Cause:** The immediate failure conditions are proven; the underlying deployment, dependency, or infrastructure cause is not proven.

**Proposed Action:** Correct the affected connection/deployment/dependency conditions in a controlled environment and verify package validation/acquisition. Do not change `MaximumErrorCount` as a substitute for fixing errors.

**Why This Action:** It addresses a demonstrated operational failure with bounded scope and provides clean performance measurement conditions.

**Expected Effect:** Very High reliability benefit; indirect performance benefit possible.  
**Implementation Effort:** Medium.  
**Change Risk:** Medium.

**Dependencies:** Access to the affected deployment/configuration and external endpoints; SSIS-TUNE-001 for complete failure exposure.  
**Baseline Metrics:** 11/500 raw non-success; per-package rates above; error-message categories and IDs.  
**Validation Test:** Execute each affected package under equivalent dependency conditions and inspect status plus event/operation messages.  
**Success Criteria:** No corresponding connection/validation errors and successful completion in the controlled retest.  
**Regression Guardrails:** Outputs, duration, downstream dependencies, and security behavior remain correct.  
**Rollback Criteria:** Restore the prior deployment/configuration if failures persist, new failures appear, or outputs change.

### SSIS-TUNE-007 — Inspect cumulative multi-hour workloads

**Priority:** P1/P2  
**Action Type:** INVESTIGATE  
**Finding:** premi, SPARTA LHA, DAILY TBS, and DWH Grading Fact have meaningful cumulative runtime.  
**Confidence:** CONFIRMED runtime impact; POSSIBLE cause.  
**Scope:** `premi`, `SPARTA_PROJECT\FACT_SPARTA_LHA_NEW.dtsx`, `DAILY_DASHBOARD_PROJECT\FACT_DD_TBS.dtsx`, and `DWH_GRADING_TBS\Fact.dtsx`.

**Evidence:** Raw cumulative runtimes are 10,284.305s, 10,133.694s, 8,116.303s, and 7,205.128s respectively. Executable statistics identify their dominant package branches but component evidence is empty.

**Current Observation:** These are high-value targets, but raw sample sizes range from two to nine executions except premi/SPARTA, and the summary population differs.

**Technical Hypothesis / Root Cause:** Data movement, SQL/source work, blocking transformations, repeated processing, or scheduling behavior may contribute; unproven.

**Proposed Action:** Profile in cumulative-runtime order after P1 baselines and observability. Change one performance variable at a time.

**Why This Action:** It assigns effort according to measured workload impact rather than static anti-pattern presence.

**Expected Effect:** High.  
**Implementation Effort:** High.  
**Change Risk:** Medium.

**Dependencies:** SSIS-TUNE-001, SSIS-TUNE-004, and reliability cleanup where applicable.  
**Baseline Metrics:** Package median/P95 where sample supports it, max, cumulative runtime, hot executable duration, volume, status.  
**Validation Test:** Controlled package-specific benchmark with comparable data and parameters.  
**Success Criteria:** Measurable duration or variability improvement without correctness or reliability regression.  
**Regression Guardrails:** Row counts, reconciliation, success rate, and downstream schedule behavior.  
**Rollback Criteria:** Revert any design change that fails guardrails or cannot demonstrate attributable benefit.

### SSIS-TUNE-008 — Validate static/runtime correlations

**Priority:** P2/P3  
**Action Type:** VALIDATE FIRST  
**Finding:** SPARTA LHA, DAILY TBS, and FACT_LKK combine runtime impact with static Sort/Lookup/Merge indicators and high Data Flow complexity.  
**Confidence:** POSSIBLE.  
**Scope:** Exact package rows in `01_static_packages/package_static_summary.csv` joined to runtime keys.

**Evidence:** SPARTA: 73 components/67 paths; DAILY: 55/50; FACT_LKK: 75/63. Runtime evidence identifies their package branches, but component/data files are empty.

**Current Observation:** Static indicators identify candidates, not proven bottlenecks.

**Technical Hypothesis / Root Cause:** Specific Lookup, Sort, Merge, or Aggregate implementation may contribute to elapsed time; not established.

**Proposed Action:** Inspect the affected Data Flows and measure component phases, rows, and reference/source behavior before any redesign.

**Why This Action:** It preserves functional ordering and avoids generic anti-pattern tuning.

**Expected Effect:** Medium.  
**Implementation Effort:** High.  
**Change Risk:** Medium/High.

**Dependencies:** SSIS-TUNE-004 and functional test data.  
**Baseline Metrics:** Component duration, rows sent, package duration, output reconciliation.  
**Validation Test:** Run one controlled component/design experiment at a time.  
**Success Criteria:** A component-level mechanism is demonstrated and an isolated change improves measured runtime.  
**Regression Guardrails:** Ordering, duplicate handling, lookup completeness, output counts, and package status.  
**Rollback Criteria:** Restore the original Data Flow if semantics change, rows are lost, or no attributable benefit appears.

### SSIS-TUNE-009 — Review warning cleanup

**Priority:** P3  
**Action Type:** DEFER  
**Finding:** Repeated unused-output and external-column synchronization warnings exist.  
**Confidence:** INFORMATIONAL/POSSIBLE for performance impact.  
**Scope:** Packages represented in 3,510 unused-output warning rows and 79 synchronization warning rows.

**Evidence:** `04_messages/event_messages.csv`, 86 and 19 execution IDs respectively.

**Current Observation:** Warnings indicate maintainability or possible avoidable metadata work; no component timing proves runtime impact.

**Technical Hypothesis / Root Cause:** Unused columns or stale metadata may add overhead or operational risk; not proven.

**Proposed Action:** Defer broad cleanup until P1 baselines are complete; review only exact columns with functional owners.

**Why This Action:** It avoids spending effort on a static/message signal that may not affect elapsed time.

**Expected Effect:** Low to Medium, unproven.  
**Implementation Effort:** Low/Medium.  
**Change Risk:** Low/Medium.

**Dependencies:** Functional mapping review and baseline evidence.  
**Baseline Metrics:** Warning recurrence, package/component duration if available, output mappings.  
**Validation Test:** Remove or refresh one safe metadata item, then execute and reconcile outputs.  
**Success Criteria:** Warning removed without functional regression and measurable benefit if performance is claimed.  
**Regression Guardrails:** No lost columns, changed mappings, or increased failures.  
**Rollback Criteria:** Restore metadata/package version on any output or validation regression.

## 10. Tuning Backlog

| Action ID | Priority | Type | Workload | Action | Confidence | Impact | Effort | Risk | Dependency |
|---|---|---|---|---|---|---|---|---|---|
| SSIS-TUNE-001 | P1 | INVESTIGATE | Runtime populations / premi | Reconcile raw and summary IDs, windows, and statuses | Confirmed gap / Possible exposure | Very High | Medium | Low | None |
| SSIS-TUNE-006 | P1 | TUNE NOW | Connection/validation failures | Repair conditions in controlled test | Confirmed | Very High reliability | Medium | Medium | 001 preferred |
| SSIS-TUNE-002 | P1 | VALIDATE FIRST | Seq_Staging_SIGAP | Profile `\\Package4` and child task | Confirmed location / Possible cause | High | Medium | Low/Medium | 001 |
| SSIS-TUNE-003 | P1 | VALIDATE FIRST | AWL Staging | Profile API-to-STG path | Confirmed impact / Possible cause | High | Medium | Low | 001 |
| SSIS-TUNE-004 | P1 | INVESTIGATE | Selected P1 packages | Add component/data/SQL observability | Confirmed gap | Very High diagnostic | Medium | Low/Medium | 001, 002/003 |
| SSIS-TUNE-007 | P1/P2 | INVESTIGATE | premi, SPARTA, DAILY, DWH Grading | Profile cumulative hotspots | Confirmed impact / Possible cause | High | High | Medium | 001, 004, 006 |
| SSIS-TUNE-005 | P2 | INVESTIGATE | Variable packages | Correlate variance drivers | Confirmed variability / Possible cause | Medium | Medium | Low | 001, 004 |
| SSIS-TUNE-008 | P2/P3 | VALIDATE FIRST | SPARTA, DAILY, FACT_LKK | Test static/runtime hypotheses | Possible | Medium | High | Medium/High | 004 |
| SSIS-TUNE-009 | P3 | DEFER | Warning packages | Review safe metadata cleanup | Informational/Possible | Low/Medium | Low/Medium | Low/Medium | 001, baselines |

## 11. Benchmark Matrix

| Action ID | Baseline Metric | Change | Test Workload | Success Metric | Regression Guardrail | Rollback Trigger |
|---|---|---|---|---|---|---|
| SSIS-TUNE-006 | 11/500 raw non-success; per-package failure IDs | Repair connection/deployment/dependency condition | Same affected packages and dependencies | Zero corresponding connection/validation errors | Status, outputs, duration | Any new failure or output change |
| SSIS-TUNE-002 | Package 6,336.348s; `\\Package4` 6,334.656s | One targeted change after profiling | `Seq_Staging_SIGAP`, comparable data | Lower branch/package duration or P95 | Output rows and success | No benefit or functional regression |
| SSIS-TUNE-003 | 34-run P95 720.6s; API path 854.562s in `1240317` | One API/process/staging change | `AWL\Staging`, comparable volume | Lower package P95/API-task duration | Data completeness and status | Failures, incomplete data, or worse duration |
| SSIS-TUNE-007 | Package cumulative runtime and hot executable duration | One package-specific change | One selected multi-hour package | Lower comparable duration/variance | Reconciliation, success rate | Guardrail regression |
| SSIS-TUNE-008 | Component metrics unavailable; package duration baseline | One Data Flow design experiment | SPARTA/DAILY/FACT_LKK | Demonstrated component improvement | Ordering, lookup completeness, outputs | Semantic or runtime regression |

## 12. Quick Wins

No sufficiently evidenced low-risk **performance** quick wins were identified.

The connection/validation repair in SSIS-TUNE-006 is a bounded, high-value reliability remediation and may be operationally quick once the responsible connection/deployment owner is identified. It must still be tested and is not presented as a proven elapsed-time optimization.

## 13. Reliability Actions

1. Reconcile the broader `premi` failure exposure before setting its final reliability priority.
2. Repair and retest the PostgreSQL/SQL connection timeout and acquisition conditions in executions `1240750`, `1240636`, `1240719`, and `1240716`.
3. Repair missing connection-manager references associated with executions `1240713`, `1240720`, and `1240739`.
4. Review the killed-session condition for `PS_AS` execution `1240698` with the responsible operational owner; do not assume it was an SSIS performance cause.
5. Monitor failure rate, validation messages, and successful completion separately from duration metrics.

## 14. Database-Side Investigation

No direct database tuning action is authorized by the current evidence. Query Store was not collected, so indexes, plans, SQL rewrites, statistics, server settings, blocking, waits, CPU, memory, and storage changes must not be prescribed.

The valid database-side task is diagnostic: capture the source query or database operation correlated to the hot SSIS executable, together with Query Store or equivalent duration/reads evidence. This is SSIS-TUNE-004 and must precede any database change.

## 15. Risks & Dependencies

- The raw/summary population mismatch can misstate frequency, cumulative runtime, and reliability; reconcile it before enterprise prioritization.
- Single-run packages do not support stable P95 or variability conclusions; repeatable baseline runs are required.
- Empty component/data evidence prevents component-level attribution and throughput calculation.
- Static Sort/Lookup/Merge/complexity indicators may be functionally required; do not remove or reconfigure them without output and ordering tests.
- Connection remediation may involve deployment/configuration ownership outside the package; coordinate with endpoint and operations owners.
- Benchmark data volume, package parameters, environment, schedule window, and dependency availability must be comparable.
- Concurrent workload overlap may affect elapsed time; record overlap rather than changing parallelism by assumption.
- Any production change must be versioned, tested, and reversible, with output reconciliation before acceptance.
- Logging/diagnostic collection may add overhead; validate its operational impact.

## 16. Deferred / Rejected Recommendations

| Recommendation | Decision | Reason |
|---|---|---|
| Change `DefaultBufferSize` or `DefaultBufferMaxRows` | DEFER | Values are not evidenced and no buffer symptom is demonstrated |
| Increase `EngineThreads` or `MaxConcurrentExecutables` | DEFER | No concurrency/resource evidence; could increase contention or destabilize workload |
| Change Lookup to Full/Partial/No Cache | DEFER | Lookup indicators and duplicate-key warnings do not prove the correct cache strategy or elapsed-time cause |
| Remove Sort, Aggregate, Merge, or Merge Join | DEFER | Functional ordering and semantics may require them; component timings are absent |
| Replace Script components | DEFER | Static Script indicator is not a demonstrated bottleneck |
| Change batch/commit/table-lock/transaction settings | DEFER | Settings are not captured and no measured write/transaction symptom supports a value change |
| Add indexes, rewrite SQL, or change execution plans | DEFER | Query Store/database evidence is absent |
| Increase package parallelism or redesign scheduling | DEFER | Overlap and resource evidence are unavailable |
| Broad cleanup of unused outputs | DEFER | Warnings are recurrent but runtime benefit is unproven; review exact safe items first |

## 17. Final Tuning Roadmap

| Order | Action | Why Now | Expected Impact | Risk | Validation |
|---:|---|---|---|---|---|
| 1 | Reconcile runtime populations | Current raw and summary totals materially disagree | Very High decision-quality | Low | Matching execution IDs, windows, counts, and statuses |
| 2 | Repair connection/validation failures | Failures are directly evidenced and contaminate reliable benchmarking | Very High reliability | Medium | Zero corresponding errors; outputs and duration intact |
| 3 | Profile `Seq_Staging_SIGAP\\Package4` | Most precise and longest observed elapsed-time concentration | High | Low/Medium | Repeatable branch/package duration and dependency metrics |
| 4 | Profile `AWL\\Staging\\API to STG` | Largest raw cumulative runtime and frequent execution | High | Low | P95/API-task duration, volume, overlap, and success rate |
| 5 | Add component/data/SQL observability | Prevents speculative design/database changes | Very High diagnostic | Low/Medium | Populated, execution-correlated evidence |
| 6 | Test one isolated change on the highest-value validated target | Makes improvement attributable and reversible | High | Medium | Before/after benchmark and guardrails |
| 7 | Extend to premi/SPARTA/DAILY/DWH Grading and static candidates | Follow measured cumulative impact after P1 evidence is clean | Medium/High | Medium/High | Comparable duration, component metrics, output correctness |
| 8 | Consider strategic refactoring only if profiling supports it | Decomposition/incremental/scheduling changes are higher risk | Medium/High potential | High | Controlled redesign benchmark and operational monitoring |
