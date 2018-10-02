/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[longrunningjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @countjobenabled INT, @countjobdisabled INT;

	DECLARE @check TABLE(
		[message] NVARCHAR(4000),
		[state] NVARCHAR(8)
	);

	DECLARE @jobactivity TABLE (
		[session_id] int NULL,
		[job_id] uniqueidentifier NULL,
		[job_name] sysname NULL,
		[run_requested_date] datetime NULL,
		[run_requested_source] sysname NULL,
		[queued_date] datetime NULL,
		[start_execution_date] datetime NULL,
		[last_executed_step_id] int NULL,
		[last_executed_step_date] datetime NULL,
		[stop_execution_date] datetime NULL,
		[next_scheduled_run_date] datetime NULL,
		[job_history_id] int NULL,
		[message] nvarchar(1024) NULL,
		[run_status] int NULL,
		[operator_id_emailed] int NULL,
		[operator_id_netsent] int NULL,
		[operator_id_paged] int NULL
	);
	
	IF ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)))) LIKE '%express%')
		INSERT INTO @check VALUES ('Express Edition Detected. No SQL Agent.', 'NA')
	ELSE
	BEGIN
		SELECT @countjobenabled=COUNT(*)
		FROM [dbo].[config_job]
		WHERE [is_enabled] = 1
			AND [max_exec_time_min] > 0

		SELECT @countjobdisabled=COUNT(*)
		FROM [dbo].[config_job]
		WHERE [is_enabled] = 0
			OR [max_exec_time_min] <= 0

		INSERT INTO @jobactivity
			EXEC msdb.dbo.sp_help_jobactivity

		INSERT INTO @check
			SELECT N'job=' 
					+ QUOTENAME([J].[job_name]) 
					+ N'; run_duration_min=' + CAST(DATEDIFF(MINUTE,[J].[start_execution_date],GETDATE()) AS NVARCHAR(20)) 
					+ N'; max_threshold_min=' + CAST([C].[max_exec_time_min] AS NVARCHAR(20)) AS [message]
				,[C].[change_state_alert] AS [state]
			FROM @jobactivity [J]
				INNER JOIN [dbo].[config_job] [C]
					ON [J].[job_id] = [C].[job_id]
			WHERE [C].[is_enabled] = 1
				AND [C].[max_exec_time_min] > 0
				AND [J].[start_execution_date] IS NOT NULL
				AND [J].[stop_execution_date] IS NULL
				AND DATEDIFF(MINUTE,[J].[start_execution_date],GETDATE()) > [C].[max_exec_time_min];
	END 

	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check 
			VALUES(CAST(@countjobenabled AS NVARCHAR(10)) 
				+ N' job(s) monitored; '
				+ CAST(@countjobdisabled AS NVARCHAR(10))
				+ ' job(s) not monitored; '
				,N'NA'
			);

	SELECT [message], [state] FROM @check;

	REVERT;
END
