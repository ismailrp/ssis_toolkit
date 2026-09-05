/*
 Additional production evidence for SSIS assessment and performance tuning

 Purpose:
   Collect the missing evidence needed to move from package/executable
   ranking to defensible component, SQL/database, scheduling, and job-step
   conclusions.

 Safety:
   - Read-only SELECT statements and metadata inspection only.
   - No data changes, configuration changes, or package execution.
   - Do not export passwords, connection strings, tokens, or sensitive values.
   - Run with the least privilege needed to read the catalog and DMVs.

 Set the same time window for all time-filtered sections. Use a window that
 includes representative normal and slow executions, not only failed runs.
*/

DECLARE @StartTime datetime2(0) = '2026-09-01 00:00:00';
DECLARE @EndTime   datetime2(0) = '2026-09-03 00:00:00';

/* ========================================================================
   A. EXACT SQL AGENT JOB / STEP MAPPING
   Save as:
     A01_sql_agent_job_steps.csv
     A02_sql_agent_job_history.csv
     A03_sql_agent_job_schedules.csv

   The job-step command is essential. A job name and generic step name alone
   cannot prove which SSIS package was launched.
   ======================================================================== */

-- A01: job steps, commands, wrappers, and retry behavior
SELECT
    j.job_id,
    j.name AS job_name,
    j.enabled AS job_enabled,
    js.step_id,
    js.step_name,
    js.subsystem,
    js.database_name,
    js.command,
    js.on_success_action,
    js.on_fail_action,
    js.retry_attempts,
    js.retry_interval,
    js.last_run_outcome
FROM msdb.dbo.sysjobs AS j
INNER JOIN msdb.dbo.sysjobsteps AS js
    ON js.job_id = j.job_id
ORDER BY j.name, js.step_id;

-- A02: time-aligned SQL Agent history, including individual step windows
;WITH H AS
(
    SELECT
        j.job_id,
        j.name AS job_name,
        h.instance_id,
        h.step_id,
        js.step_name,
        js.subsystem,
        js.command,
        h.run_status,
        CASE h.run_status
            WHEN 0 THEN 'Failed'
            WHEN 1 THEN 'Succeeded'
            WHEN 2 THEN 'Retry'
            WHEN 3 THEN 'Canceled'
            WHEN 4 THEN 'In Progress'
            ELSE 'Unknown'
        END AS run_status_desc,
        h.run_date,
        h.run_time,
        h.run_duration,
        ca.step_start_time,
        DATEADD
        (
            SECOND,
            (h.run_duration / 10000) * 3600
              + ((h.run_duration % 10000) / 100) * 60
              + (h.run_duration % 100),
            ca.step_start_time
        ) AS step_end_time,
        h.message
    FROM msdb.dbo.sysjobhistory AS h
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = h.job_id
    LEFT JOIN msdb.dbo.sysjobsteps AS js
        ON js.job_id = h.job_id
       AND js.step_id = h.step_id
    CROSS APPLY
    (
        SELECT DATETIMEFROMPARTS
        (
            h.run_date / 10000,
            (h.run_date % 10000) / 100,
            h.run_date % 100,
            h.run_time / 10000,
            (h.run_time % 10000) / 100,
            h.run_time % 100,
            0
        ) AS step_start_time
    ) AS ca
    WHERE h.run_date >= 19000101
)
SELECT *
FROM H
WHERE step_start_time < @EndTime
  AND step_end_time >= @StartTime
ORDER BY step_start_time, job_name, step_id;

-- A03: schedules and next-run metadata
SELECT
    j.job_id,
    j.name AS job_name,
    j.enabled AS job_enabled,
    s.schedule_id,
    s.name AS schedule_name,
    s.enabled AS schedule_enabled,
    s.freq_type,
    s.freq_interval,
    s.freq_subday_type,
    s.freq_subday_interval,
    s.freq_relative_interval,
    s.freq_recurrence_factor,
    s.active_start_date,
    s.active_start_time,
    s.active_end_date,
    s.active_end_time,
    js.next_run_date,
    js.next_run_time
FROM msdb.dbo.sysjobs AS j
LEFT JOIN msdb.dbo.sysjobschedules AS js
    ON js.job_id = j.job_id
LEFT JOIN msdb.dbo.sysschedules AS s
    ON s.schedule_id = js.schedule_id
ORDER BY j.name, s.name;

/* ========================================================================
   B. SSISDB RUNTIME DETAIL
   Save as:
     B01_ssis_executions.csv
     B02_executable_statistics.csv
     B03_execution_component_phases.csv
     B04_execution_data_statistics.csv
     B05_ssis_event_messages.csv
     B06_ssis_operation_messages.csv
   ======================================================================== */

-- B01: exact SSIS execution population and timing
SELECT
    e.execution_id,
    e.folder_name,
    e.project_name,
    e.package_name,
    e.environment_folder_name,
    e.environment_name,
    e.executed_as_name,
    e.use32bitruntime,
    e.reference_id,
    e.start_time,
    e.end_time,
    DATEDIFF_BIG(millisecond, e.start_time, e.end_time) AS duration_ms,
    e.status,
    e.caller_name,
    e.server_name
FROM [SSISDB].catalog.executions AS e
WHERE e.start_time < @EndTime
  AND e.end_time >= @StartTime
ORDER BY e.start_time, e.execution_id;

-- B02: executable timing for the same execution population
SELECT
    es.*
FROM [SSISDB].catalog.executable_statistics AS es
INNER JOIN [SSISDB].catalog.executions AS e
    ON e.execution_id = es.execution_id
WHERE e.start_time < @EndTime
  AND e.end_time >= @StartTime
ORDER BY es.execution_id, es.start_time, es.execution_path;

-- B03: component phase timing. This is required for component attribution.
SELECT
    cp.*
FROM [SSISDB].catalog.execution_component_phases AS cp
INNER JOIN [SSISDB].catalog.executions AS e
    ON e.execution_id = cp.execution_id
WHERE e.start_time < @EndTime
  AND e.end_time >= @StartTime
ORDER BY cp.execution_id;

-- B04: rows sent and Data Flow path volume. This is required for throughput.
SELECT
    ds.*
FROM [SSISDB].catalog.execution_data_statistics AS ds
INNER JOIN [SSISDB].catalog.executions AS e
    ON e.execution_id = ds.execution_id
WHERE e.start_time < @EndTime
  AND e.end_time >= @StartTime
ORDER BY ds.execution_id;

-- B05: SSIS event messages for the same execution window
SELECT
    em.*
FROM [SSISDB].catalog.event_messages AS em
WHERE em.message_time >= @StartTime
  AND em.message_time < @EndTime
ORDER BY em.message_time, em.operation_id, em.event_message_id;

-- B06: SSIS operation messages for the same execution window
SELECT
    om.*
FROM [SSISDB].catalog.operation_messages AS om
WHERE om.message_time >= @StartTime
  AND om.message_time < @EndTime
ORDER BY om.message_time, om.operation_id;

/* ========================================================================
   C. SSIS DEPLOYMENT / CONFIGURATION CONTEXT
   Save as:
     C01_ssis_folders.csv
     C02_ssis_projects.csv
     C03_ssis_packages.csv
     C04_ssis_environments.csv
     C05_ssis_environment_variables_metadata.csv

   Do not export sensitive environment variable values.
   ======================================================================== */

SELECT * FROM [SSISDB].catalog.folders ORDER BY name;

SELECT *
FROM [SSISDB].catalog.projects
ORDER BY folder_id, name;

SELECT *
FROM [SSISDB].catalog.packages
ORDER BY project_id, name;

SELECT *
FROM [SSISDB].catalog.environments
ORDER BY folder_id, name;

SELECT
    folder_name,
    environment_name,
    variable_name,
    description,
    type,
    sensitive,
    value_set,
    validation_status,
    last_deployed_time
FROM [SSISDB].catalog.environment_variables
ORDER BY folder_name, environment_name, variable_name;

/* ========================================================================
   D. QUERY STORE / DATABASE-SIDE EVIDENCE
   Save as:
     D01_query_store_database_state.csv
     D02_query_store_options_<database>.csv
     D03_query_store_top_queries_<database>.csv

   Run D02 and D03 in each source/destination database used by the selected
   P1 packages. Query Store evidence must be time-aligned or otherwise
   correlated to the SSIS execution/task.
   ======================================================================== */

-- D01: identify online databases and Query Store availability
SELECT
    name AS database_name,
    state_desc,
    is_read_only,
    recovery_model_desc,
    compatibility_level,
    is_query_store_on
FROM sys.databases
WHERE state_desc = 'ONLINE'
ORDER BY name;

-- D02: run in each relevant source/destination database
SELECT
    DB_NAME() AS database_name,
    actual_state_desc,
    desired_state_desc,
    readonly_reason,
    current_storage_size_mb,
    max_storage_size_mb,
    stale_query_threshold_days,
    interval_length_minutes,
    size_based_cleanup_mode_desc,
    query_capture_mode_desc
FROM sys.database_query_store_options;

-- D03: run in each relevant source/destination database
-- Durations are in microseconds; reads are logical reads per execution.
SELECT TOP (200)
    DB_NAME() AS database_name,
    q.query_id,
    p.plan_id,
    qt.query_sql_text,
    rs.count_executions,
    rs.avg_duration,
    rs.last_duration,
    rs.max_duration,
    rs.avg_cpu_time,
    rs.avg_logical_io_reads,
    rs.avg_physical_io_reads,
    rs.first_execution_time,
    rs.last_execution_time
FROM sys.query_store_runtime_stats AS rs
INNER JOIN sys.query_store_plan AS p
    ON p.plan_id = rs.plan_id
INNER JOIN sys.query_store_query AS q
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON qt.query_text_id = q.query_text_id
WHERE rs.last_execution_time >= @StartTime
  AND rs.first_execution_time < @EndTime
ORDER BY rs.avg_duration * rs.count_executions DESC;

/* ========================================================================
   E. TIME-OF-RUN SQL / RESOURCE SNAPSHOTS
   Save while a representative package is actively running:
     E01_active_requests_<execution_id>_<timestamp>.csv
     E02_waiting_tasks_<execution_id>_<timestamp>.csv
     E03_io_snapshot_<timestamp>.csv
     E04_wait_stats_<timestamp>.csv

   These DMVs are point-in-time or cumulative snapshots. Capture at least
   once during a normal run and once during a slow run. Do not interpret a
   single snapshot as historical proof.
   ======================================================================== */

-- E01: active requests and SQL text while the package is running
SELECT
    r.session_id,
    r.request_id,
    r.status,
    r.command,
    r.database_id,
    DB_NAME(r.database_id) AS database_name,
    r.start_time,
    r.total_elapsed_time,
    r.cpu_time,
    r.logical_reads,
    r.reads,
    r.writes,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    r.percent_complete,
    SUBSTRING
    (
        st.text,
        (r.statement_start_offset / 2) + 1,
        CASE r.statement_end_offset
            WHEN -1 THEN LEN(CONVERT(nvarchar(max), st.text))
            ELSE (r.statement_end_offset - r.statement_start_offset) / 2 + 1
        END
    ) AS running_statement,
    st.text AS batch_text
FROM sys.dm_exec_requests AS r
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id <> @@SPID
ORDER BY r.total_elapsed_time DESC;

-- E02: current waits and blockers
SELECT
    wt.session_id,
    wt.wait_duration_ms,
    wt.wait_type,
    wt.blocking_session_id,
    wt.resource_description,
    DB_NAME(r.database_id) AS database_name,
    r.command,
    r.status
FROM sys.dm_os_waiting_tasks AS wt
LEFT JOIN sys.dm_exec_requests AS r
    ON r.session_id = wt.session_id
WHERE wt.session_id <> @@SPID
ORDER BY wt.wait_duration_ms DESC;

-- E03: file I/O counters. These are cumulative since startup/file creation.
SELECT
    DB_NAME(vfs.database_id) AS database_name,
    mf.type_desc,
    mf.name AS logical_file_name,
    mf.physical_name,
    vfs.num_of_reads,
    vfs.num_of_bytes_read,
    vfs.io_stall_read_ms,
    vfs.num_of_writes,
    vfs.num_of_bytes_written,
    vfs.io_stall_write_ms,
    vfs.io_stall,
    vfs.size_on_disk_bytes
FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
INNER JOIN sys.master_files AS mf
    ON mf.database_id = vfs.database_id
   AND mf.file_id = vfs.file_id
ORDER BY vfs.io_stall DESC;

-- E04: cumulative wait counters. Capture before and after a test window if
-- this evidence is used; do not infer a cause from one server-wide snapshot.
SELECT
    wait_type,
    waiting_tasks_count,
    wait_time_ms,
    signal_wait_time_ms
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN
(
    'BROKER_EVENTHANDLER', 'BROKER_RECEIVE_WAITFOR', 'BROKER_TASK_STOP',
    'BROKER_TO_FLUSH', 'BROKER_TRANSMITTER', 'CHECKPOINT_QUEUE',
    'CHKPT', 'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT', 'CLR_SEMAPHORE',
    'DBMIRROR_EVENTS_QUEUE', 'DBMIRRORING_CMD', 'DIRTY_PAGE_POLL',
    'DISPATCHER_QUEUE_SEMAPHORE', 'FT_IFTS_SCHEDULER_IDLE_WAIT',
    'HADR_CLUSAPI_CALL', 'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
    'LAZYWRITER_SLEEP', 'LOGMGR_QUEUE', 'ONDEMAND_TASK_QUEUE',
    'REQUEST_FOR_DEADLOCK_SEARCH', 'SLEEP_TASK', 'SOS_WORK_DISPATCHER',
    'SP_SERVER_DIAGNOSTICS_SLEEP', 'SQLTRACE_BUFFER_FLUSH',
    'WAITFOR', 'XE_DISPATCHER_WAIT', 'XE_TIMER_EVENT'
)
ORDER BY wait_time_ms DESC;

/* ========================================================================
   F. OPTIONAL WRAPPER / CALL-JOB DEPENDENCIES
   Save as:
     F01_job_step_wrapper_references.csv

   Use only when A01 shows that a job step invokes a stored procedure or
   wrapper instead of naming the SSIS package directly. Review output for
   sensitive literals before sharing it.
   ======================================================================== */

SELECT
    DB_NAME() AS database_name,
    SCHEMA_NAME(o.schema_id) AS schema_name,
    o.name AS object_name,
    o.type_desc,
    m.definition
FROM sys.objects AS o
INNER JOIN sys.sql_modules AS m
    ON m.object_id = o.object_id
WHERE m.definition LIKE '%SSISDB%'
   OR m.definition LIKE '%catalog.create_execution%'
   OR m.definition LIKE '%dtexec%'
ORDER BY schema_name, object_name;

/*
 Minimum package to send for a stronger report:

   A01, A02, A03
   B01, B02, B03, B04, B05, B06
   D01, D02, D03 for databases used by the selected P1 packages
   E01/E02 during representative normal and slow runs

 Highest-value additions for the current assessment:
   1. B03 and B04: component timing and rows sent are currently empty.
   2. A01 and A02: exact SQL Agent command and time-aligned history.
   3. D03: database-side evidence for the hot executable/task.
   4. E01 and E02: active SQL and waits while the hot package is running.
*/
