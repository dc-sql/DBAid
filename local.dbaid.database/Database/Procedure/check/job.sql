/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[job]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	DECLARE @countjob INT;

	SELECT @countjob=COUNT(*)
	FROM [msdb].[dbo].[sysjobs]
	WHERE [enabled] = 1

	;WITH [jobset]
	AS
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [J].[name] ORDER BY [T].[run_datetime] DESC) AS [row]
			,[J].[job_id]
			,[J].[name]
			,[H].[run_status]
			,[T].[run_datetime]
		FROM [msdb].[dbo].[sysjobs] [J]
			INNER JOIN [msdb].[dbo].[sysjobhistory] [H]
				ON [J].[job_id] = [H].[job_id]
			CROSS APPLY (SELECT CAST(CAST([H].[run_date] AS CHAR(8)) + ' ' + STUFF(STUFF(REPLACE(STR([H].[run_time],6,0),' ','0'),3,0,':'),6,0,':') AS DATETIME)) [T]([run_datetime])
		WHERE [J].[enabled] = 1
			AND [H].[step_id] = 0
	)
	INSERT INTO @check
		SELECT N'job=' + QUOTENAME([J].[name]) COLLATE Database_Default
				+ N'; state=' 
				+ CASE [J].[run_status] 
					WHEN 0 THEN N'FAIL'
					WHEN 1 THEN N'SUCCESS'
					WHEN 2 THEN N'RETRY'
					WHEN 3 THEN N'CANCEL'
					ELSE N'UNKNOWN' END AS [message]
			,CASE WHEN [J].[run_status] IN (0) THEN [C].[check_job_state] ELSE 'OK' END AS [state]
		FROM [jobset] [J]
			INNER JOIN [setting].[check_job] [C]
				ON [J].[job_id] = [C].[job_id]
		WHERE [J].[row] = 1
			AND [C].[check_job_enabled] = 1
			AND [J].[run_status] = 0;

	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(CAST(@countjob AS NVARCHAR(10)) + N' enabled job(s)',N'NA');

	SELECT [message], [state] FROM @check;
END
