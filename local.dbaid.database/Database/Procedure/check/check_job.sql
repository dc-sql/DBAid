/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[job]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	DECLARE @countjobenabled INT, @countjobdisabled INT;

	SELECT @countjobenabled=COUNT(*)
	FROM [dbo].[config_job]
	WHERE [is_enabled] = 1

	SELECT @countjobdisabled=COUNT(*)
	FROM [dbo].[config_job]
	WHERE [is_enabled] = 0

	;WITH [jobset]
	AS
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [J].[name] ORDER BY [H].[run_date] DESC, [H].[run_time] DESC) AS [row]
			,[J].[job_id]
			,[J].[name]
			,[H].[run_status]
		FROM [msdb].[dbo].[sysjobs] [J]
			INNER JOIN [msdb].[dbo].[sysjobhistory] [H]
				ON [J].[job_id] = [H].[job_id]
		WHERE [J].[enabled] = 1
			AND [H].[step_id] = 0
	)
	INSERT INTO @check
		SELECT N'job=' + QUOTENAME([J].[name]) COLLATE Database_Default
				+ N'; state=FAIL' AS [message]
			,[C].[change_state_alert] AS [state]
		FROM [jobset] [J]
			INNER JOIN [dbo].[config_job] [C]
				ON [J].[job_id] = [C].[job_id]
		WHERE [J].[row] = 1
			AND [C].[is_enabled] = 1
			AND [J].[run_status] = 0 /* 0=FAIL */;

	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check 
		VALUES(CAST(@countjobenabled AS NVARCHAR(10)) 
			+ N' job(s) monitored; ' 
			+ CAST(@countjobdisabled AS NVARCHAR(10))
			+ ' job(s) not monitored; '
			,N'NA');

	SELECT [message], [state] FROM @check;

	REVERT;
END
