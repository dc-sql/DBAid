﻿/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_agentjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @countjob INT, @runtimejob INT, @statusjob INT;
	DECLARE @check_output TABLE([state] VARCHAR(8), [message] VARCHAR(4000));

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

	SELECT @countjob=COUNT(*)
	FROM [msdb].[dbo].[sysjobs]
	WHERE [enabled] = 1

	SELECT @runtimejob=COUNT(*)
	FROM [checkmk].[config_agentjob]
	WHERE [runtime_check_enabled] = 1

	SELECT @statusjob=COUNT(*)
	FROM [checkmk].[config_agentjob]
	WHERE [state_check_enabled] = 1

	IF NOT ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS VARCHAR(128)))) LIKE '%express%')
	BEGIN
		INSERT INTO @jobactivity 
			EXEC msdb.dbo.sp_help_jobactivity
	END
	ELSE
	BEGIN
		INSERT INTO @check_output 
		VALUES('NA', 'SQL Server Express Edition detected.');
	END

	;WITH [job_data]
	AS
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [J].[name] ORDER BY [H].[run_date] DESC, [H].[run_time] DESC) AS [row]
			,[J].[job_id]
			,[J].[name]
			,CASE [H].[run_status]
					WHEN 0 THEN 'FAIL'
					WHEN 1 THEN 'SUCCESS'
					WHEN 2 THEN 'RETRY'
					WHEN 3 THEN 'CANCEL'
					ELSE 'UNKNOWN' END AS [run_status]
			,[run_datetime] = CAST(CAST([H].[run_date] AS CHAR(8)) + ' ' + STUFF(STUFF(REPLACE(STR([H].[run_time],6,0),' ','0'),3,0,':'),6,0,':') AS DATETIME)
			,[H].[run_duration]
		FROM [msdb].[dbo].[sysjobs] [J]
			INNER JOIN [msdb].[dbo].[sysjobhistory] [H]
				ON [J].[job_id] = [H].[job_id]
		WHERE [J].[enabled] = 1
			AND [H].[step_id] = 0
	)
	INSERT INTO @check_output
		SELECT CASE 
				WHEN [J].[run_status] = 'FAIL' 
					THEN [C].[state_check_alert] 
				WHEN [X].[start_execution_date] IS NOT NULL 
					AND [X].[stop_execution_date] IS NULL 
					AND CAST(DATEDIFF(MINUTE,[X].[start_execution_date],GETDATE()) AS VARCHAR(10)) > [C].[runtime_check_min] 
					THEN [C].[runtime_check_alert] 
				ELSE 'OK' END AS [state]
			,'job=' + QUOTENAME([J].[name]) COLLATE DATABASE_DEFAULT
				+ ';state=' 
				+ [J].[run_status]
				+ ';runtime_min='
				+ CASE WHEN [X].[start_execution_date] IS NOT NULL AND [X].[stop_execution_date] IS NULL
					THEN CAST(DATEDIFF(MINUTE,[X].[start_execution_date],GETDATE()) AS VARCHAR(10))
					ELSE CAST([J].[run_duration]/100.00%100 AS VARCHAR(10)) END 
				+ ';runtime_check_min=' 
				+ CAST([C].[runtime_check_min] AS VARCHAR(10)) AS [message]
		FROM [job_data] [J]
			INNER JOIN [checkmk].[config_agentjob] [C]
				ON [J].[name] = [C].[name]
			LEFT JOIN @jobactivity [X]
				ON [J].[job_id] = [X].[job_id]
		WHERE [J].[row] = 1
			AND ([J].[run_status] = 'FAIL' OR ([X].[start_execution_date] IS NOT NULL AND [X].[stop_execution_date] IS NULL))
			AND ([C].[state_check_enabled] = 1 OR [C].[runtime_check_enabled] = 1);

	IF ((SELECT COUNT(*) FROM @check_output) < 1 AND @countjob > 0)
	BEGIN
		INSERT INTO @check_output 
		VALUES('OK', CAST(@countjob AS VARCHAR(10)) + ' agent job(s) enabled; ' 
			+ CAST(@statusjob AS VARCHAR(10)) + ' monitoring status; ' 
			+ CAST(@runtimejob AS VARCHAR(10)) + ' monitoring runtime');
	END
	ELSE
	BEGIN
		INSERT INTO @check_output 
		VALUES('NA', 'No agent job(s) enabled;');
	END

	SELECT [state], [message] FROM @check_output;
END