/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_backup]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @backup_enabled INT, @backup_disabled INT, @major_version INT;
	DECLARE @preferred_backup TABLE ([db_name] SYSNAME, [preferred_backup] BIT);
	DECLARE @last_backup TABLE ([db_name] SYSNAME, [full_backup_date] DATETIME, [diff_backup_date] DATETIME, [tran_backup_date] DATETIME);
	DECLARE @check_output TABLE ([message] NVARCHAR(4000), [state] NVARCHAR(8));

	SELECT @major_version = [major] FROM [system].[get_product_version]();

	IF @major_version >= 11
	BEGIN
		INSERT INTO @preferred_backup
			EXEC sp_executesql N'SELECT [name], [sys].[fn_hadr_backup_is_preferred_replica]([name]) AS [preferred_backup] FROM [sys].[databases]';
	END

	;WITH [LastBackup]
	AS 
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [DB].[name], [BS].[type] ORDER BY [BS].[backup_finish_date] DESC) AS [row]
			,[DB].[name]
			,CASE WHEN [BS].[type] = 'D' THEN [BS].[backup_finish_date] ELSE NULL END AS [full_backup_date]
			,CASE WHEN [BS].[type] = 'I' THEN [BS].[backup_finish_date] ELSE NULL END AS [diff_backup_date]
			,CASE WHEN [BS].[type] = 'L' THEN [BS].[backup_finish_date] ELSE NULL END AS [tran_backup_date]
		FROM [sys].[databases] [DB] 
			INNER JOIN [msdb].[dbo].[backupset] [BS]
				ON [DB].[name] = [BS].[database_name]
			OUTER APPLY(SELECT [preferred_backup] FROM @preferred_backup WHERE [db_name] = [CC].[ci_name]) AS [AG]
		WHERE ([AG].[preferred_backup] = 1 OR [AG].[preferred_backup] IS NULL)
	)
	INSERT INTO @last_backup
		SELECT [name]
			,SUM([full_backup_date])
			,SUM([diff_backup_date])
			,SUM([tran_backup_date])
		FROM [LastBackup] 
		WHERE [row] = 1
		GROUP BY [name];

	SELECT QUOTENAME([LB].[db_name]) 
		+ '; last_full=' + CASE WHEN [CD].[check_backup_full_hour] IS NOT NULL THEN CONVERT(VARCHAR(20), [LB].[full_backup_date], 120) ELSE 'NULL' END
		+ '; last_diff=' + CASE WHEN [CD].[check_backup_diff_hour] IS NOT NULL THEN CONVERT(VARCHAR(20), [LB].[diff_backup_date], 120) ELSE 'NULL' END
		+ '; last_tran=' + CASE WHEN [CD].[check_backup_tran_hour] IS NOT NULL THEN CONVERT(VARCHAR(20), [LB].[tran_backup_date], 120) ELSE 'NULL' END
		AS [message]
		,CASE WHEN ([CD].[check_backup_full_hour] IS NOT NULL AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) AND [LB].[full_backup_date] < DATEADD(HOUR, -[CD].[check_backup_full_hour], GETDATE()))
			OR ([CD].[check_backup_diff_hour] IS NOT NULL AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) AND [LB].[full_backup_date] < DATEADD(HOUR, -[CD].[check_backup_diff_hour]) AND [LB].[diff_backup_date] < DATEADD(HOUR, -[CD].[check_backup_diff_hour], GETDATE()))
			OR ([CD].[check_backup_tran_hour] IS NOT NULL AND [DB].[recovery_model] IN (1,2) AND [LB].[tran_backup_date] < DATEADD(HOUR, -[CD].[check_backup_tran_hour], GETDATE()))
			THEN [CD].[check_backup_alert]
			ELSE 'OK' END AS [state]
	FROM sys.databases [DB]
		INNER JOIN [checkmk].[configuration_database] [CD]
			ON [DB].[name] = [CD].[name]
		LEFT JOIN @last_backup [LB]
			ON [DB].[name] = [LB].[db_name]
	WHERE [CD].[check_backup_enabled] = 1

	IF (SELECT COUNT(*) FROM @check_output WHERE [state] != 'OK') = 0
	BEGIN
		SELECT @backup_enabled = COUNT(*) FROM [checkmk].[configuration_database] WHERE [backup_check_enabled] = 1;
		SELECT @backup_disabled = COUNT(*) FROM [checkmk].[configuration_database] WHERE [backup_check_enabled] = 0;

		INSERT INTO @check_output VALUES('Monitoring databases for backup(s)'
			+ '; enabled=' + CAST(@backup_enabled AS VARCHAR(8)) 
			+ '; disabled=' + CAST(@backup_disabled AS VARCHAR(8)),'NA');
	END

	SELECT [message], [state] FROM @check_output WHERE [state] != 'OK';
END
