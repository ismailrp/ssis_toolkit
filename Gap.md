• Not from the current evidence. The reports contain package names and SSIS execution paths, but no SQL Server Agent job
or step metadata.

Available mapping:

Evidence field Result
━━━━━━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
package_name SSIS package name
─────────────────────────── ───────────────────────────────────────────────────────────────────
caller_name BUMITAMA\sqlservice for 499 executions; BUMITAMA\admin.ajay for 1
─────────────────────────── ───────────────────────────────────────────────────────────────────
execution_id SSIS execution identifier
─────────────────────────── ───────────────────────────────────────────────────────────────────
SQL Agent job name Not collected
─────────────────────────── ───────────────────────────────────────────────────────────────────
SQL Agent step name Not collected
─────────────────────────── ───────────────────────────────────────────────────────────────────
Schedule/history metadata Not collected

For example, AWL\Staging.dtsx can be mapped to caller BUMITAMA\sqlservice, but not to a specific SQL Agent job or
step.

To produce the requested mapping, we need SQL Agent metadata from msdb, especially:

- msdb.dbo.sysjobs
- msdb.dbo.sysjobsteps
- msdb.dbo.sysjobhistory

The job step command should be matched to the SSIS catalog path:

Folder / Project / Package

The current limitation is documented by the absence of job/step fields in assessments/EVSET-001/03_runtime/
executions.csv.

---

• The three reports cover some areas well, but several requested topics are only partial or not assessable from the
evidence.

Requested area Coverage Assessment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Package inventory and categorization Covered Reports include folders, projects, packages,
ISPACs, runtime packages, complexity, and
rankings.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Data sources and targets Partial Sources/destinations are mentioned for
investigation, but there is no complete
source-to-target inventory.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Schedules Partial / not analyzed Frequency and observation windows are
discussed, but SQL Agent schedules were not
included in the reports.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Data Flow transformations Partial Sort, Lookup, Merge, Aggregate, Script,
component counts, and path counts are covered
as static indicators.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Blocking vs. non-blocking components Not covered Component phase evidence is empty, so this was
not determined.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Incremental loads Not covered No reliable evidence of incremental-load
design or behavior.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Error handling Partial Failures, validation errors, warnings, and
connection problems are covered. Package
error-handling design is not fully reviewed.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
DOP / concurrency Not covered Overlap is mentioned as a limitation, but DOP
and concurrency were not measured.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Buffer sizing Not covered DefaultBufferSize, DefaultBufferMaxRows, and
related settings were unavailable.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Async components Not covered No component-level runtime evidence exists.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Memory pressure Not covered No memory/resource evidence was collected.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
SQL Agent dependencies Not covered The separate job mapping file contains
candidates, but the three reports do not
include exact job dependencies.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
SQL Agent retries Not covered Retry configuration was not included in the
reports.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Job windows and overlaps Partial Scheduling overlap is identified as an
evidence gap, not analyzed.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Deadlocks and contention Not covered No blocking, deadlock, or contention evidence
was available.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Database indexing/statistics/constraints Not covered No database-side evidence supports these
conclusions.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Batch/bulk-load settings Not covered Settings were unavailable and no values were
prescribed.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
TempDB and transaction log Not covered No TempDB or log-growth evidence was
collected.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Isolation levels/transactions Not covered Not assessed.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
CPU, memory, I/O, latency Not covered Explicitly identified as unavailable.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Network bandwidth Not covered Not collected.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Project/package parameters Partial Parameter inventory exists, but parameter
impact was not analyzed in depth.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Environments Partial SSISDB environment files were empty, so
deployed environment values could not be
assessed.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
SSISDB/deployment review Covered Folders, projects, packages, ISPAC inventory,
parsing status, and deployment limitations are
covered.
────────────────────────────────────────── ──────────────────────── ────────────────────────────────────────────────
Logging Partial Event/operation messages and logging gaps are
covered; component logging is missing.

Overall, the reports are strong for:

- Package and workload inventory
- Runtime duration and cumulative-runtime ranking
- Executable hotspot identification
- Failure/reliability analysis
- Static-to-runtime correlation
- Evidence limitations and tuning priorities

They do not yet provide a complete production architecture or infrastructure assessment. The largest gaps are SQL
Agent orchestration, component-level runtime, database impact, resource pressure, and network behavior.

The additional SQL file queries/assessor_additional_evidence.sql contains queries to collect the missing evidence. The
SQL Agent job/step candidates are documented separately in PACKAGE_JOB_STEP_MAPPING.md.
