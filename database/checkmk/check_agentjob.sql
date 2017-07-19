/*
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
	DECLARE @check_output TABLE([message] VARCHAR(4000)
								,[state] VARCHAR(8));

	DECLARE @xpresults TABLE ([job_id] UNIQUEIDENTIFIER
							,[last_run_date] INT
							,[last_run_time] INT
							,[next_run_date] INT
							,[next_run_time] INT
							,[next_run_schedule_id] INT
							,[requested_to_run] INT
							,[request_source] INT
							,[request_source_id] SYSNAME COLLATE database_default NULL
							,[running] INT
							,[current_step] INT
							,[current_retry_attempt] INT
							,[job_state] INT);

	SELECT @countjob=COUNT(*)
	FROM [msdb].[dbo].[sysjobs]
	WHERE [enabled] = 1

	SELECT @runtimejob=COUNT(*)
	FROM [checkmk].[configuration_agentjob]
	WHERE [runtime_check_enabled] = 1

	SELECT @statusjob=COUNT(*)
	FROM [checkmk].[configuration_agentjob]
	WHERE [state_check_enabled] = 1

	IF NOT ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS VARCHAR(128)))) LIKE '%express%')
		INSERT INTO @xpresults
			EXECUTE [master].[dbo].[xp_sqlagent_enum_jobs] 1, '$(DatabaseName)_sa', NULL;

	;WITH [job_data]
	AS
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [J].[name] ORDER BY [T].[run_datetime] DESC) AS [row]
			,[J].[job_id]
			,[J].[name]
			,CASE [H].[run_status]
					WHEN 0 THEN 'FAIL'
					WHEN 1 THEN 'SUCCESS'
					WHEN 2 THEN 'RETRY'
					WHEN 3 THEN 'CANCEL'
					ELSE 'UNKNOWN' END AS [run_status]
			,[T].[run_datetime]
			,[H].[run_duration]
		FROM [msdb].[dbo].[sysjobs] [J]
			INNER JOIN [msdb].[dbo].[sysjobhistory] [H]
				ON [J].[job_id] = [H].[job_id]
			CROSS APPLY (SELECT CAST(CAST([H].[run_date] AS CHAR(8)) + ' ' + STUFF(STUFF(REPLACE(STR([H].[run_time],6,0),' ','0'),3,0,':'),6,0,':') AS DATETIME)) [T]([run_datetime])
		WHERE [J].[enabled] = 1
			AND [H].[step_id] = 0
	)
	INSERT INTO @check_output
		SELECT 'job=' + QUOTENAME([J].[name]) COLLATE Database_Default
				+ ';state=' 
				+ [J].[run_status]
				+ ';runtime_min='
				+ CASE [X].[running] 
					WHEN 1 THEN CAST(DATEDIFF(MINUTE,[X].[last_run_date],GETDATE()) AS VARCHAR(10))
					ELSE ([J].[run_duration]/100.00%100) END 
				+ ';runtime_check_min=' 
				+ [C].[runtime_check_min] AS [message]
			,CASE WHEN [J].[run_status] = 0 THEN [C].[state_check_alert] 
				WHEN [X].[running] = 1 AND CAST(DATEDIFF(MINUTE,[X].[last_run_date],GETDATE()) AS VARCHAR(10)) > [C].[runtime_check_min] THEN [C].[runtime_check_alert] 
				ELSE 'OK' END AS [state]
		FROM [job_data] [J]
			INNER JOIN [checkmk].[configuration_agentjob] [C]
				ON [J].[name] = [C].[name]
			LEFT JOIN @xpresults [X]
				ON [J].[job_id] = [X].[job_id]
		WHERE [J].[row] = 1
			AND ([J].[run_status] = 0 OR [X].[running] = 1)
			AND ([C].[state_check_enabled] = 1 OR [C].[runtime_check_enabled] = 1);

	IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output 
		VALUES(CAST(@countjob AS VARCHAR(10)) + ' agent job(s) enabled; ' 
			+ CAST(@statusjob AS VARCHAR(10)) + 'monitoring status; ' 
			+ CAST(@runtimejob AS VARCHAR(10)) + 'monitoring runtime' ,N'NA');

	SELECT [message], [state] FROM @check_output;
END
