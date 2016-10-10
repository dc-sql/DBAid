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

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	DECLARE @xpresults TABLE ([job_id] UNIQUEIDENTIFIER
							,[last_run_date] INT
							,[last_run_time] INT
							,[next_run_date] INT
							,[next_run_time] INT
							,[next_run_schedule_id] INT
							,[requested_to_run] INT
							,[request_source] INT
							,[request_source_id] sysname COLLATE database_default NULL
							,[running] INT
							,[current_step] INT
							,[current_retry_attempt] INT
							,[job_state] INT);
	
	IF ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)))) LIKE '%express%')
		INSERT INTO @check VALUES ('Express Edition Detected. No SQL Agent.', 'NA')
	ELSE
	BEGIN
		INSERT INTO @xpresults
			EXECUTE [master].[dbo].[xp_sqlagent_enum_jobs] 1, '$(DatabaseName)_sa', NULL;

		INSERT INTO @check
			SELECT N'job=' 
					+ QUOTENAME([C].[job_name]) 
					+ N'; state='  
					+ CASE [X].[job_state]
						WHEN 0 THEN N'OTHER'
						WHEN 1 THEN N'EXECUTING'
						WHEN 2 THEN N'WAITING'
						WHEN 3 THEN N'RETRYING'
						WHEN 4 THEN N'IDLE'
						WHEN 5 THEN N'SUSPENDED'
						WHEN 6 THEN N'WAITING'
						WHEN 7 THEN N'FINISHING'
						ELSE N'UNKNOWN' END
					+ N'; run_duration_min=' + CAST(DATEDIFF(MINUTE,[T].[last_exec_date],GETDATE()) AS NVARCHAR(20)) 
					+ N'; max_threshold_min=' + CAST([C].[max_exec_time_min] AS NVARCHAR(20)) AS [message]
				,CASE WHEN DATEDIFF(MINUTE,[T].[last_exec_date],GETDATE()) >= [C].[max_exec_time_min] THEN [C].[change_state_alert] ELSE N'OK' END AS [state]
			FROM @xpresults [X]
				INNER JOIN [dbo].[config_job] [C]
					ON [X].[job_id] = [C].[job_id]
				CROSS APPLY (SELECT ISNULL(MAX([start_execution_date]),GETDATE()) FROM [msdb].[dbo].[sysjobactivity] WHERE [job_id] = [X].[job_id]) [T]([last_exec_date])
			WHERE [C].[is_enabled] = 1
				AND [C].[max_exec_time_min] != 0
				AND ISNULL([X].[running],0) = 1
				AND DATEDIFF(MINUTE,[T].[last_exec_date],GETDATE()) > [C].[max_exec_time_min];
	END 

	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(N'Job(s) not currently executing.',N'NA');

	SELECT [message], [state] FROM @check;

	REVERT;
END
