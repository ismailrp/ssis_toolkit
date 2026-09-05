# SSIS Performance Assessment, Bottleneck Analysis & Tuning Roadmap

Act as a **Principal SQL Server / SSIS Performance Engineer** conducting an enterprise SSIS performance assessment.

Analyze the complete evidence folder provided with this prompt.

This is an **evidence-based performance assessment**, not a generic SSIS best-practice review.

Do not modify, regenerate, or recollect evidence.

Do not ask for additional evidence before completing the assessment from what is currently available.

If an important conclusion cannot be proven because evidence is missing or insufficient, complete the analysis anyway and record the limitation under **Evidence Gaps**.

---

# 1. Primary Objective

Determine, from the available evidence:

1. Which SSIS workloads are actually slow, unstable, failing, or operationally significant.
2. Where execution time is concentrated.
3. Which packages, executables, Data Flows, or components are most likely responsible.
4. Whether static package design characteristics correlate with observed runtime behavior.
5. Which findings are proven versus suspected.
6. Which optimization opportunities should be investigated or implemented first.
7. How each proposed optimization should be validated using before/after measurements.

The final deliverable must help an assessor answer:

> Where is the performance problem, what evidence supports it, what is the likely root cause, what should be done next, and how will we prove that the change improved performance?

---

# 2. Assessment Philosophy

Always analyze runtime behavior before static design characteristics.

Use this investigation order:

Evidence Coverage
→ Workload Baseline
→ Runtime Ranking
→ Hot Package
→ Hot Executable
→ Hot Data Flow / Component where evidence exists
→ Static Design Correlation
→ Root Cause Hypothesis
→ Recommendation
→ Priority
→ Validation

Do NOT begin with an anti-pattern checklist and assume every detected design characteristic is a performance problem.

For example:

- presence of Sort does not prove Sort is a bottleneck
- presence of Lookup does not prove Lookup is inefficient
- presence of Script Component does not prove row-by-row processing
- presence of Merge does not prove Merge is expensive

Static evidence identifies **risk or investigation targets**.

Runtime evidence determines whether those risks correlate with actual workload behavior.

---

# 3. Evidence Boundaries

Use only evidence actually present in the assessment folder.

Expected evidence may include:

## Manifest / collection evidence

- collector environment
- server identity
- ISPAC inventory
- static file inventory
- evidence manifest

## Static package evidence

- extracted ISPAC contents
- package static summary
- package/project artifacts where available

The static package summary may provide indicators such as:

- executable node count
- Data Flow component count
- Data Flow path count
- connection manager count
- Sort indicator
- Aggregate indicator
- Lookup indicator
- Merge indicator
- Script indicator
- parsing status

Do not assume that configuration properties not explicitly captured by the evidence are known.

## SSISDB inventory

Evidence may include:

- folders
- projects
- packages
- environments
- environment variables
- object parameters

## SSISDB runtime evidence

Evidence may include:

- executions
- package runtime summary
- executable statistics
- slow executables
- execution component phases
- execution data statistics

## Messages

Evidence may include:

- event messages
- operation messages

## Optional SQL evidence

Query Store evidence may exist when collection was enabled.

If it does not exist, do not infer SQL Server query performance.

---

# 4. Evidence Qualification

Before analyzing performance, create an **Evidence Coverage Matrix**.

Use:

| Evidence Category | Status | Records / Objects | Assessment Use | Limitation |
|---|---|---:|---|---|

Classify each category as:

- AVAILABLE
- PARTIAL
- EMPTY
- FAILED
- NOT COLLECTED
- NOT APPLICABLE

At minimum evaluate:

- ISPAC inventory
- static package summary
- SSISDB package/project inventory
- executions
- executable statistics
- component phases
- data statistics
- event messages
- operation messages
- Query Store evidence

Do not silently ignore zero-row files.

A zero-row runtime evidence file is an evidence result, not proof that no performance problem exists.

Explain how unavailable or empty evidence affects the confidence of subsequent conclusions.

---

# 5. Evidence Integrity

Check for collection problems before interpreting results.

Identify where possible:

- failed ISPAC extraction
- failed DTSX parsing
- missing runtime files
- query collection error files
- zero-row runtime evidence
- inconsistent package/project naming
- packages present statically but absent from runtime history
- runtime packages without corresponding static evidence

Do not treat collection failure as workload health.

For example:

> No component phase records available

does NOT mean:

> No component-level performance problems exist.

---

# 6. Workload Characterization

Establish the runtime baseline before identifying bottlenecks.

Using execution evidence, calculate where possible:

- execution count
- successful executions
- failed / unexpected executions
- success rate
- failure rate
- average duration
- median duration
- P95 duration
- minimum duration
- maximum duration
- runtime spread / variability
- cumulative runtime
- execution frequency within the captured observation window

Derive median, P95, cumulative runtime, and variability from raw execution records when sufficient observations exist.

Do not fabricate statistics when sample size is insufficient.

Explicitly show the observation window represented by the collected evidence.

---

# 7. Runtime Performance Ranking

Rank workloads using multiple perspectives.

Do not rank packages only by average duration.

Produce at least:

## A. Longest-running packages

## B. Largest cumulative runtime consumers

Cumulative Runtime approximately:

Execution Count × observed runtime

Prefer calculation from individual execution records when possible.

## C. Most frequently executed packages

## D. Most unstable packages

Identify packages with substantial runtime variation when sufficient execution samples exist.

## E. Failure-prone packages

This distinction is important because:

- a 60-minute monthly package
- and a 10-minute package running many times per day

represent different performance priorities.

Do not assume the longest single execution is automatically the highest tuning priority.

---

# 8. Runtime Performance Table

Create:

| Rank | Folder | Project | Package | Executions | Avg | Median | P95 | Max | Cumulative Runtime | Failure Rate | Runtime Stability | Priority |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|---|

Only populate metrics supported by evidence.

Use `N/A` where calculation is not defensible.

---

# 9. Package-to-Executable Analysis

For high-priority packages, inspect executable statistics.

Determine:

- slowest executable paths
- repeatedly expensive executables
- executable duration
- execution result
- relationship between executable runtime and total package runtime

Where timestamps allow meaningful comparison, calculate:

Executable Contribution % =
Executable Duration / Package Duration × 100

Use this carefully.

SSIS executables may overlap because of parallel execution.

Therefore:

> Do NOT sum executable durations and assume they equal package elapsed duration.

Explicitly identify parallel or overlapping timing where observable.

The objective is to determine:

> Where is package elapsed time concentrated?

---

# 10. Component-Level Analysis

When `execution_component_phases` contains usable evidence, inspect:

- package
- task
- subcomponent
- phase
- duration

Identify recurring component-phase hotspots.

Do not claim component-level bottlenecks when component phase evidence is unavailable.

When `execution_data_statistics` contains usable evidence, inspect:

- package
- task
- source component
- destination component
- Data Flow path
- rows sent

Use this to understand data movement and relative volume.

Where both duration and row-count evidence can be defensibly correlated, discuss throughput.

Do NOT calculate rows/sec by joining unrelated executions, tasks, or paths.

---

# 11. Static-to-Runtime Correlation

Use static evidence only after identifying runtime hotspots.

Inspect high-impact packages for static indicators such as:

- Sort
- Aggregate
- Lookup
- Merge / Merge Join
- Script

Also consider:

- unusually high Data Flow component count
- unusually high Data Flow path count
- unusually high executable count
- package complexity relative to peers

For every static finding ask:

1. Is the affected package actually slow or unstable?
2. Is the related executable expensive?
3. Is component-level runtime evidence available?
4. Does the static characteristic plausibly explain observed behavior?
5. Is there enough evidence to call it a bottleneck?

Static indicators without runtime correlation must remain:

POSSIBLE or INFORMATIONAL.

---

# 12. Confidence Model

Every significant finding must have one of these confidence levels.

## CONFIRMED

Direct runtime evidence demonstrates the performance condition and evidence reasonably identifies its location or mechanism.

## HIGHLY LIKELY

Runtime evidence demonstrates the performance condition and multiple evidence sources strongly support the proposed cause, but direct causal proof is incomplete.

## POSSIBLE

A plausible performance risk exists but available runtime evidence cannot establish causality.

## INFORMATIONAL

Relevant design, inventory, operational, or evidence observation that is not currently demonstrated to affect performance.

Never upgrade a finding merely because it matches a common SSIS best practice.

---

# 13. Bottleneck Classification

Classify every major finding into the most defensible layer:

- SSIS PACKAGE / CONTROL FLOW
- SSIS DATA FLOW
- SSIS COMPONENT
- SQL / DATABASE SIDE
- OPERATIONAL / SCHEDULING
- RELIABILITY
- UNKNOWN / INSUFFICIENT EVIDENCE

Use SQL / DATABASE SIDE only when available evidence actually supports that conclusion.

If Query Store or comparable database-side evidence is unavailable, state:

> Database-side performance cannot be conclusively assessed from the current evidence set.

Do not infer CPU pressure, memory pressure, disk latency, blocking, SQL execution-plan problems, or missing indexes unless corresponding evidence exists.

---

# 14. Root Cause Analysis

For every CONFIRMED and HIGHLY LIKELY finding construct the following chain:

**Symptom**

What performance behavior was observed?

**Observed Evidence**

Which files, execution IDs, packages, paths, tasks, components, or records demonstrate it?

**Bottleneck Location**

Where is elapsed time or instability concentrated?

**Technical Mechanism**

What mechanism could explain the behavior?

**Root Cause**

What does the available evidence allow us to conclude?

**Recommended Action**

What should be changed or investigated?

**Expected Effect**

Describe qualitatively unless quantitative improvement can be defensibly calculated.

Use:

- Very High
- High
- Medium
- Low

Do not invent percentage improvements.

**Validation**

How should the recommendation be tested?

---

# 15. Observation vs Interpretation vs Recommendation

Keep these concepts separate.

Example:

**Observation**

Package A averages significantly longer than comparable workloads and one executable accounts for most of its elapsed runtime.

**Interpretation**

The package bottleneck is concentrated in that executable rather than distributed across the package.

**Static Correlation**

The affected package contains a Lookup indicator.

**Hypothesis**

Lookup/reference processing may contribute to the expensive Data Flow.

**Recommendation**

Investigate the Lookup implementation and reference query before changing its cache strategy.

**Confidence**

HIGHLY LIKELY or POSSIBLE depending on available component/runtime evidence.

Do not collapse all of these into:

> Lookup is causing the package to run slowly.

unless the evidence actually proves that statement.

---

# 16. Failure and Warning Analysis

Inspect execution status, event messages, and operation messages.

Identify:

- failed executions
- unexpected termination
- recurring errors
- recurring warnings
- repeated failure patterns
- package/task names associated with failures

Separate:

PERFORMANCE ISSUE

from:

RELIABILITY ISSUE

A failing package is not automatically a performance bottleneck.

However, repeated failures or retries may create operational workload and should be reported.

---

# 17. Query Store / Database-Side Analysis

Perform this section ONLY when Query Store evidence exists.

Inspect available evidence for:

- execution count
- weighted average duration
- logical reads
- expensive recurring SQL

Attempt package/SQL correlation only when evidence provides a defensible relationship.

Do not assume every expensive Query Store query belongs to SSIS.

If Query Store evidence is absent, state the limitation and continue the SSIS assessment.

Do NOT make speculative missing-index recommendations without supporting database-side evidence.

---

# 18. Anti-Pattern Matrix

Create:

| Finding | Folder | Project | Package | Executable / Component | Static Evidence | Runtime Evidence | Impact | Confidence | Recommendation |
|---|---|---|---|---|---|---|---|---|---|

Important:

This table is a **correlation matrix**, not a generic SSIS checklist.

A package containing Sort/Lookup/Merge/Script but showing no meaningful runtime impact should not be promoted into the Top Bottlenecks section.

---

# 19. Prioritization Model

Prioritize findings based on available evidence using:

1. observed performance impact
2. cumulative workload impact
3. execution frequency
4. runtime instability
5. reliability impact
6. confidence
7. implementation effort
8. implementation risk

Use:

## P0 — Critical

Severe demonstrated issue requiring immediate attention.

Use sparingly.

## P1 — High Priority

Strongly evidenced performance issue with meaningful optimization value.

## P2 — Medium Priority

Meaningful improvement opportunity requiring further validation or moderate effort.

## P3 — Optimization / Investigation

Lower-impact, preventive, architectural, or insufficiently proven opportunity.

A theoretical anti-pattern must NOT automatically receive P0 or P1.

---

# 20. Recommendation Rules

Never provide generic tuning advice detached from evidence.

Do NOT recommend changing values such as:

- DefaultBufferSize
- DefaultBufferMaxRows
- EngineThreads
- MaxConcurrentExecutables
- RowsPerBatch
- MaximumInsertCommitSize
- Lookup cache strategy
- transaction settings
- parallelism

unless those settings are actually available in evidence and there is a demonstrated reason to investigate them.

If the current evidence only identifies that a package contains a Lookup, for example, recommend:

> Inspect Lookup configuration and reference query for package X.

Do NOT claim:

> Change Lookup to Full Cache.

unless evidence supports that exact recommendation.

Likewise:

- do not remove Sort if ordering may be functionally required
- do not remove Aggregate because it is blocking
- do not replace Script solely because Script exists
- do not increase concurrency solely to reduce elapsed time
- do not recommend arbitrary buffer-size values

Preserve functional correctness over theoretical performance improvement.

---

# 21. Quick Wins

Only classify something as a Quick Win when:

- the problem is supported by evidence
- implementation scope is reasonably clear
- implementation risk appears low
- before/after measurement is possible

Do not fill this section merely because the report template requires recommendations.

If no defensible quick wins exist, state that further package-level inspection is required.

---

# 22. Strategic Improvements

Identify broader opportunities only when evidence suggests them.

Examples may include:

- package decomposition
- scheduling redesign
- reducing repeated processing
- redesigning high-complexity Data Flows
- incremental processing
- SQL pushdown investigation
- improving runtime observability

Clearly label strategic recommendations that require additional evidence before implementation.

---

# 23. Validation / Benchmark Plan

Every P0/P1 recommendation must have a validation plan.

Define:

**Baseline**

Use available metrics such as:

- package duration
- executable duration
- execution success
- runtime variance
- rows sent where available

**Change**

Describe the exact proposed tuning action or investigation.

**Re-test**

Use comparable workload and data volume where possible.

**Success Criteria**

Specify which observed metric should improve.

Do not invent a target percentage unless a business SLA or evidence supports one.

Prefer:

> P95 package duration decreases without increasing failure rate.

over:

> Performance should improve by 40%.

---

# 24. Health Score

Do NOT invent an arbitrary 0–100 health score.

Only provide a numerical score if a reproducible scoring methodology can be constructed from the available evidence.

If sufficient evidence does not exist, report:

> **Health Score: Not Scorable From Available Evidence**

Instead provide an evidence-based assessment such as:

- CRITICAL
- NEEDS ATTENTION
- MODERATE
- HEALTHY WITH OPTIMIZATION OPPORTUNITIES
- INSUFFICIENT EVIDENCE

Explain the reason for the classification.

---

# 25. Evidence Citation Requirement

Every major finding must cite the exact evidence source.

Use references such as:

- evidence filename
- folder/project/package
- execution_id
- execution_path
- task/component
- relevant record identifier

Examples:

> Evidence: `03_runtime/executions.csv`, execution_id 12345

> Evidence: `03_runtime/executable_statistics.csv`, execution_id 12345, execution_path `\Package\Data Flow Task`

> Evidence: `01_static_packages/package_static_summary.csv`, Project X / Package Y

Do not say:

> Based on the evidence...

without identifying which evidence supports the conclusion.

---

# 26. Required Final Report

Create or replace:

`FINAL_ASSESSMENT_REPORT.md`

Do not modify evidence files.

Use the following structure.

# SSIS Performance Assessment, Bottleneck Analysis & Tuning Roadmap

## 1. Executive Summary

Summarize:

- overall assessment
- evidence coverage
- workload observation window
- number of projects/packages assessed
- most significant demonstrated bottlenecks
- most important risks
- highest-value tuning opportunities
- major limitations

The executive summary must distinguish:

**What is proven**

from:

**What still requires validation**

---

## 2. Evidence Coverage & Assessment Confidence

Include the Evidence Coverage Matrix.

Explain limitations that materially affect conclusions.

---

## 3. SSIS Environment & Workload Overview

Summarize:

- folders
- projects
- packages
- available execution history
- workload frequency
- success/failure profile

---

## 4. Runtime Performance Baseline

Provide:

- longest-running workloads
- cumulative runtime consumers
- frequent workloads
- unstable workloads
- failure-prone workloads

---

## 5. Runtime Performance Ranking

Provide the package ranking table.

---

## 6. Top Performance Findings

Rank only meaningful findings.

For every finding provide:

### Finding

### Priority

P0 / P1 / P2 / P3

### Confidence

CONFIRMED / HIGHLY LIKELY / POSSIBLE / INFORMATIONAL

### Affected Workload

Folder / Project / Package / Executable

### Observation

### Evidence

### Bottleneck Location

### Technical Interpretation

### Root Cause / Hypothesis

### Recommendation

### Expected Benefit

Very High / High / Medium / Low

### Implementation Effort

High / Medium / Low

### Change Risk

High / Medium / Low

### Validation Method

Do not force exactly 10 findings.

If only 4 meaningful findings are supported by evidence, report 4.

Quality and defensibility are more important than filling a Top 10 list.

---

## 7. Package & Executable Hotspot Analysis

Analyze the packages contributing most strongly to observed runtime problems.

---

## 8. Data Flow / Component Analysis

Use component phase and data statistics only when available.

Explicitly state when logging/evidence is insufficient for component-level conclusions.

---

## 9. Static-to-Runtime Correlation

Correlate static package indicators with observed runtime behavior.

Separate:

- correlated findings
- unconfirmed design risks
- informational package complexity

---

## 10. Reliability & Error Findings

Separate performance and reliability findings.

---

## 11. Database-Side Findings

Populate only when database-side evidence exists.

Otherwise state:

> Database-side performance is outside the conclusively assessable scope of the current evidence set.

---

## 12. Quick Wins

Table:

| Priority | Recommendation | Affected Workload | Evidence | Expected Impact | Effort | Risk | Validation |
|---|---|---|---|---|---|---|---|

---

## 13. Strategic Improvements

Separate evidence-backed strategic improvements from areas requiring further investigation.

---

## 14. Performance Tuning Roadmap

Create:

| Priority | Finding | Workload | Bottleneck Layer | Evidence | Impact | Confidence | Effort | Risk | Action | Validation |
|---|---|---|---|---|---|---|---|---|---|---|

Group recommendations into:

### P0 — Immediate

### P1 — High Priority

### P2 — Medium Priority

### P3 — Optimization / Investigation

---

## 15. Validation & Benchmark Plan

Define before/after measurements for high-priority tuning actions.

---

## 16. Evidence Gaps

Only list gaps that materially prevent stronger conclusions.

For every gap explain:

1. what is missing
2. which conclusion it prevents
3. whether current findings remain usable despite the gap
4. what additional evidence would increase confidence

Do NOT generically request every possible SQL Server or SSIS diagnostic.

---

## 17. Final Assessment Conclusion

Answer explicitly:

1. Which SSIS packages are actually slow?
2. Which workloads consume the most cumulative runtime?
3. Which packages are unstable or failure-prone?
4. Which executables account for most observed package runtime?
5. Are component-level bottlenecks identifiable from current evidence?
6. Which static design risks correlate with runtime hotspots?
7. Which findings are CONFIRMED?
8. Which findings remain hypotheses?
9. Is there evidence that the problem is SSIS-side, database-side, or currently indeterminate?
10. What should be tuned or investigated first?
11. How should improvement be measured after tuning?

---

# 27. Final Quality Rules

Before completing the report:

- inspect all relevant evidence files
- do not stop at manifest or summary CSVs
- cross-check aggregated summaries against raw execution evidence
- distinguish zero evidence from evidence of zero problems
- never invent metrics
- never invent package/component names
- never invent configuration values
- never invent percentage improvements
- never convert a static indicator into a confirmed bottleneck without runtime support
- never make database-side conclusions without database-side evidence
- prefer measured runtime evidence over theoretical best practices
- explicitly state uncertainty
- preserve traceability from every important conclusion back to evidence

The final report must be suitable for use as an **enterprise SSIS performance assessment and tuning decision document**, not merely as an AI-generated list of SSIS best practices.