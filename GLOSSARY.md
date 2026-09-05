# SSIS Performance Assessment Glossary

Short explanations of terms used in:

- `FINAL_ASSESSMENT_REPORT.md`
- `EXECUTIVE_ASSESSMENT_SUMMARY.md`
- `PERFORMANCE_TUNING_PLAN.md`

## Performance Metrics

### Average / Mean

The total duration divided by the number of executions. Useful for general comparison, but can be distorted by unusually slow or fast runs.

### Median / P50

The middle execution duration after sorting all durations. Half the runs were faster and half were slower. It often represents a typical run better than the average.

### P90

The duration at or below which approximately 90% of executions completed. About 10% of executions took longer.

### P95

The duration at or below which approximately 95% of executions completed. About 5% of executions took longer. P95 is useful for identifying slow-tail behavior, but needs enough executions to be meaningful.

### Minimum / Min

The shortest observed execution duration.

### Maximum / Max

The longest observed execution duration. A single maximum does not prove that the workload is usually slow.

### Runtime Spread / Variability

How much execution duration changes from run to run. A large gap between median, P95, and maximum indicates inconsistent runtime.

### Coefficient of Variation / CV

A relative measure of runtime variability: standard deviation divided by average duration. A higher CV means greater variation compared with the average.

### Cumulative Runtime

The sum of durations across executions. It identifies workloads that consume the most total elapsed execution time during the observation period.

### Execution Frequency

How many times a package ran during the captured period. A moderately slow package that runs frequently may matter more than a very slow package that runs once.

### Throughput

The amount of data processed per unit of time, such as rows per second. It cannot be calculated reliably in these reports because data-statistics evidence was empty.

### Executable Contribution

Executable duration divided by package duration, expressed as a percentage. It helps locate elapsed time inside a package. Nested SSIS executables can overlap, so their percentages must not be added together.

## SSIS Terms

### Package

An SSIS workflow containing control-flow tasks and, often, Data Flow Tasks.

### Executable

An SSIS runtime object that performs work, such as a task, container, or nested package element. The runtime evidence records executable paths and durations.

### Control Flow

The part of an SSIS package that controls task order, branching, loops, dependencies, and parallel execution.

### Data Flow

An SSIS pipeline that moves and transforms rows between sources and destinations.

### Data Flow Component

An individual source, transformation, lookup, sort, merge, or destination inside a Data Flow.

### Data Flow Path

The connection that carries rows from one Data Flow component to another.

### ISPAC

An SSIS project deployment package containing deployed project and package artifacts.

### DTSX

The XML-based file format used for an individual SSIS package.

### Lookup

An SSIS transformation that finds matching reference data for incoming rows. Its presence alone does not prove a performance problem.

### Sort

A transformation that orders rows. It may be required by downstream logic; removing it without testing can change behavior.

### Aggregate

A transformation that groups rows and calculates values such as sums or counts.

### Merge / Merge Join

Transformations that combine sorted data streams. They may be functionally required and are not automatically bottlenecks.

### Script Component / Script Task

An SSIS component or task containing custom code. Its existence does not prove row-by-row processing or poor performance.

### Connection Manager

An SSIS object that stores connection information used by tasks and components to access databases, files, APIs, or other sources.

### Validation

The stage where SSIS checks package components, metadata, and connections before or during execution.

## Evidence Terms

### Raw Execution Evidence

Individual execution records containing package, status, timestamps, duration, and execution ID. This is the primary authority for runtime findings.

### Package Runtime Summary

Aggregated package-level runtime records. In this assessment it contains a different population from the 500-row raw execution extract, so the two sources must not be combined without reconciliation.

### Observation Window

The start and end period represented by the collected execution evidence. The raw sample covers approximately 2026-09-01 10:05 through 2026-09-02 09:55 +07:00.

### MaxExecutions

The maximum number of raw execution records collected by the collector. The configured value was 500. It is a collection limit, not a statement that only 500 executions occurred.

### Capped Evidence

Evidence limited by a maximum row or execution count. Capped evidence can support the observed sample but may not represent the complete workload history.

### Static Evidence

Package design information extracted from ISPAC/DTSX files, such as node counts and component indicators. Static evidence identifies risks and investigation targets; it does not prove runtime impact.

### Runtime Evidence

Evidence captured while packages execute, such as duration, status, executable timing, messages, and rows processed.

### Component Phase Evidence

Runtime timing for phases of individual Data Flow components. The corresponding file was empty in this assessment, so component-level bottlenecks could not be confirmed.

### Data Statistics Evidence

Runtime information about rows sent between Data Flow sources and destinations. The corresponding file was empty, so throughput and row-volume correlations could not be calculated.

### Evidence Gap

A missing or incomplete evidence source that prevents a stronger conclusion. An evidence gap is not proof that no problem exists.

### Query Store

SQL Server feature that records query execution history and performance information. Query Store was not collected, so database-side causes could not be assessed conclusively.

### Evidence Coverage Matrix

A table showing whether each evidence category is available, partial, empty, failed, or not collected, and explaining how that affects confidence.

## Status, Confidence, and Priority

### Success Rate

Successful executions divided by total executions, expressed as a percentage.

### Failure Rate

Failed or unexpected executions divided by total executions. A failure is primarily a reliability issue, not automatically a performance issue.

### CONFIRMED

Direct evidence demonstrates the condition and sufficiently identifies its location or mechanism.

### HIGHLY LIKELY

Runtime evidence demonstrates the condition and multiple evidence sources strongly support the suspected mechanism, but causal proof is incomplete.

### POSSIBLE

A technically plausible risk or explanation that the available evidence cannot prove.

### INFORMATIONAL

An observed design, inventory, warning, or evidence fact without demonstrated performance impact.

### P0 — Critical

A severe demonstrated issue requiring immediate attention. Used sparingly.

### P1 — High Priority

A strongly evidenced performance or reliability issue with meaningful operational impact.

### P2 — Medium Priority

A useful optimization or investigation with moderate impact, evidence strength, effort, or risk.

### P3 — Investigation / Optimization

A lower-impact, preventive, strategic, or insufficiently proven opportunity.

## Tuning Plan Terms

### TUNE NOW

Evidence is strong enough for a controlled implementation and benchmark. It does not mean an untested production change.

### VALIDATE FIRST

A strong hypothesis exists, but additional evidence or a controlled experiment is required before changing production design.

### INVESTIGATE

Evidence identifies a meaningful target, but the root cause or best change is still uncertain.

### DEFER

Do not act yet because evidence, expected benefit, risk, or dependencies do not justify implementation.

### Baseline

The measured starting condition before a change, including duration, status, variability, executable timing, and data volume where available.

### Benchmark

A controlled before-and-after comparison using comparable package, data volume, parameters, environment, and execution conditions.

### Change Isolation

Changing one meaningful performance variable at a time so that any improvement or regression can be attributed reasonably.

### Success Criteria

The measurable conditions required to accept a change, such as lower P95 duration with no increase in failures.

### Regression Guardrail

A metric or behavior that must not worsen, such as output correctness, row counts, success rate, or downstream processing.

### Rollback Criteria

Predefined conditions requiring the change to be reversed, such as functional differences, new failures, or no measurable benefit.

### Implementation Wave

A staged group of actions ordered by evidence, dependency, risk, and expected value. The plan uses Wave 0 for measurement, Wave 1 for high-confidence tuning, Wave 2 for secondary optimization, and Wave 3 for strategic improvement.

### Reliability Remediation

Work intended to reduce failures, connection errors, validation errors, retries, and operational interruptions.

### Performance Remediation

Work intended to reduce elapsed time, cumulative runtime, variability, or improve throughput.

## Important Distinction

The presence of a static component such as Lookup, Sort, Merge, Aggregate, or Script is an investigation clue—not proof of a bottleneck. Runtime evidence must identify the affected workload, and controlled testing must demonstrate that a proposed change improves performance without harming correctness or reliability.
