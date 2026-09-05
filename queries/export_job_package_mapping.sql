/*
 SSIS package -> SQL Agent job/step export

 Purpose:
   Produce the metadata needed to map SQL Agent jobs/steps to SSISDB
   folder/project/package executions.

 Safety:
   - Read-only SELECT statements only.
   - No passwords, connection strings, tokens, or package data are exported.
   - Run on the SQL Server that hosts both msdb and SSISDB.

 Before running:
   1. Set @StartTime and @EndTime to the same period as the SSIS evidence.
   2. Execute each result set and save it as the indicated CSV file.
   3. If the SSIS catalog database is not named SSISDB, replace [SSISDB].

 Recommended output files:
   01_sql_agent_job_steps.csv
   02_sql_agent_job_history.csv
   03_sql_agent_job_schedules.csv
   04_ssis_executions.csv
   05_candidate_job_package_mapping.csv
*/

DECLARE @StartTime datetime2(0) = '2026-09-01 00:00:00';
DECLARE @EndTime   datetime2(0) = '2026-09-03 00:00:00';

/* 01_sql_agent_job_steps.csv
   The command column is the key field. It may contain an SSIS catalog path,
   a catalog.create_execution call, a dtexec command, or a wrapper reference.
*/
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

/* 02_sql_agent_job_history.csv
   Includes step start/end timestamps derived from SQL Agent's integer fields.
   step_id = 0 is the overall job outcome; step_id > 0 is an individual step.
*/
;WITH JobHistory AS
(
    SELECT
        j.job_id,
        j.name AS job_name,
        h.instance_id,
        h.step_id,
        js.step_name,
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
        ca.start_time,
        DATEADD
        (
            SECOND,
            (h.run_duration / 10000) * 3600
              + ((h.run_duration % 10000) / 100) * 60
              + (h.run_duration % 100),
            ca.start_time
        ) AS end_time,
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
        ) AS start_time
    ) AS ca
    WHERE h.run_date >= 19000101
      AND ca.start_time < @EndTime
      AND DATEADD
          (
              SECOND,
              (h.run_duration / 10000) * 3600
                + ((h.run_duration % 10000) / 100) * 60
                + (h.run_duration % 100),
              ca.start_time
          ) >= @StartTime
)
SELECT
    job_id,
    job_name,
    instance_id,
    step_id,
    step_name,
    run_status,
    run_status_desc,
    run_date,
    run_time,
    run_duration,
    start_time,
    end_time,
    message
FROM JobHistory
ORDER BY start_time, job_name, step_id;

/* 03_sql_agent_job_schedules.csv */
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

/* 04_ssis_executions.csv
   SSISDB execution records to correlate with SQL Agent history by time and
   to identify the exact folder/project/package path.
*/
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
    CASE e.status
        WHEN 1 THEN 'Created'
        WHEN 2 THEN 'Running'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'Failed'
        WHEN 5 THEN 'Pending'
        WHEN 6 THEN 'Ended Unexpectedly'
        WHEN 7 THEN 'Succeeded'
        WHEN 8 THEN 'Stopping'
        WHEN 9 THEN 'Completed'
        ELSE 'Unknown'
    END AS status_desc,
    e.caller_name,
    e.server_name
FROM [SSISDB].catalog.executions AS e
WHERE e.start_time < @EndTime
  AND e.end_time >= @StartTime
ORDER BY e.start_time, e.execution_id;

/* 05_candidate_job_package_mapping.csv
   Time-aligned candidates. This is a candidate mapping, not proof:
   SQL Agent history does not retain the SSIS execution_id.

   A strong candidate is a step whose execution window contains the SSIS
   execution window. The command and exact catalog path must be reviewed to
   confirm the relationship.
*/
;WITH JobHistory AS
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
        ca.start_time,
        DATEADD
        (
            SECOND,
            (h.run_duration / 10000) * 3600
              + ((h.run_duration % 10000) / 100) * 60
              + (h.run_duration % 100),
            ca.start_time
        ) AS end_time
    FROM msdb.dbo.sysjobhistory AS h
    INNER JOIN msdb.dbo.sysjobs AS j
        ON j.job_id = h.job_id
    INNER JOIN msdb.dbo.sysjobsteps AS js
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
        ) AS start_time
    ) AS ca
    WHERE h.step_id > 0
      AND h.run_date >= 19000101
)
SELECT
    e.execution_id,
    e.folder_name,
    e.project_name,
    e.package_name,
    e.start_time AS ssis_start_time,
    e.end_time AS ssis_end_time,
    e.status AS ssis_status,
    jh.job_id,
    jh.job_name,
    jh.step_id,
    jh.step_name,
    jh.subsystem,
    jh.start_time AS agent_step_start_time,
    jh.end_time AS agent_step_end_time,
    jh.run_status AS agent_run_status,
    jh.run_status_desc AS agent_run_status_desc,
    jh.instance_id,
    jh.command,
    CASE
        WHEN LOWER(jh.command) LIKE '%' + LOWER(e.package_name) + '%'
          OR LOWER(jh.step_name) = LOWER(REPLACE(e.package_name, '.dtsx', ''))
        THEN 'STRONG_NAME_OR_COMMAND_MATCH'
        ELSE 'TIME_OVERLAP_ONLY'
    END AS candidate_match_type
FROM [SSISDB].catalog.executions AS e
INNER JOIN JobHistory AS jh
    ON jh.start_time <= e.start_time
   AND jh.end_time >= e.end_time
WHERE e.start_time < @EndTime
  AND e.end_time >= @StartTime
ORDER BY e.start_time, e.execution_id, candidate_match_type DESC, jh.job_name, jh.step_id;

/*
 Optional follow-up when a step command calls a wrapper procedure or script:

   SELECT OBJECT_SCHEMA_NAME(object_id) AS schema_name,
          OBJECT_NAME(object_id) AS object_name,
          definition
   FROM [YourDatabase].sys.sql_modules
   WHERE definition LIKE '%create_execution%'
      OR definition LIKE '%SSISDB%';

 Export the matching procedure definition separately, after reviewing it for
 secrets or sensitive connection information.
*/
