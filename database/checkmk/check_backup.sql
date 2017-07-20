/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_backup]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @backup_enabled INT, @backup_disabled INT, @major_version INT;
	DECLARE @preferred_backup TABLE ([name] SYSNAME, [preferred_backup] BIT);
	DECLARE @last_backup TABLE ([name] SYSNAME, [full_backup_date] DATETIME, [diff_backup_date] DATETIME, [tran_backup_date] DATETIME);
	DECLARE @check_output TABLE([state] VARCHAR(8), [message] VARCHAR(4000));

	SELECT @major_version = [major] FROM [system].[get_product_version]();

	IF @major_version >= 11
	BEGIN
		INSERT INTO @preferred_backup
			EXEC sp_executesql N'SELECT [name], [sys].[fn_hadr_backup_is_preferred_replica]([name]) AS [preferred_backup] FROM [sys].[databases]';
	END

	;WITH [LastBackup]
	AS 
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [DB].[name], [B].[type] ORDER BY [B].[backup_finish_date] DESC) AS [row]
			,[DB].[name]
			,CASE WHEN [B].[type] = 'D' THEN [B].[backup_finish_date] ELSE NULL END AS [full_backup_date]
			,CASE WHEN [B].[type] = 'I' THEN [B].[backup_finish_date] ELSE NULL END AS [diff_backup_date]
			,CASE WHEN [B].[type] = 'L' THEN [B].[backup_finish_date] ELSE NULL END AS [tran_backup_date]
		FROM [sys].[databases] [DB] 
			INNER JOIN [msdb].[dbo].[backupset] [B]
				ON [DB].[name] = [B].[database_name]
			OUTER APPLY(SELECT [preferred_backup] FROM @preferred_backup WHERE [name] = [DB].[name]) AS [AG]
		WHERE ([AG].[preferred_backup] = 1 OR [AG].[preferred_backup] IS NULL)
	)
	INSERT INTO @last_backup
		SELECT [name]
			,MAX([full_backup_date])
			,MAX([diff_backup_date])
			,MAX([tran_backup_date])
		FROM [LastBackup] 
		WHERE [row] = 1
		GROUP BY [name];

	INSERT INTO @check_output
		SELECT CASE WHEN ([C].[backup_check_full_hour] IS NOT NULL 
					AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) 
					AND [LB].[full_backup_date] < DATEADD(HOUR, -[C].[backup_check_full_hour], GETDATE()))
				OR ([C].[backup_check_diff_hour] IS NOT NULL 
					AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) 
					AND [LB].[full_backup_date] < DATEADD(HOUR, -[C].[backup_check_diff_hour], GETDATE()) 
					AND [LB].[diff_backup_date] < DATEADD(HOUR, -[C].[backup_check_diff_hour], GETDATE()))
				OR ([C].[backup_check_tran_hour] IS NOT NULL 
					AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) 
					AND [DB].[recovery_model] IN (1,2) 
					AND [LB].[tran_backup_date] < DATEADD(HOUR, -[C].[backup_check_tran_hour], GETDATE()))
				THEN [C].[backup_check_alert]
				ELSE 'OK' END AS [state]
			,QUOTENAME([LB].[name]) 
			+ '; last_full=' + CASE WHEN [C].[backup_check_full_hour] IS NOT NULL THEN CONVERT(VARCHAR(20), [LB].[full_backup_date], 120) ELSE 'NULL' END
			+ '; last_diff=' + CASE WHEN [C].[backup_check_diff_hour] IS NOT NULL THEN CONVERT(VARCHAR(20), [LB].[diff_backup_date], 120) ELSE 'NULL' END
			+ '; last_tran=' + CASE WHEN [C].[backup_check_tran_hour] IS NOT NULL THEN CONVERT(VARCHAR(20), [LB].[tran_backup_date], 120) ELSE 'NULL' END
			AS [message]
		FROM sys.databases [DB]
			INNER JOIN [checkmk].[configuration_database] [C]
				ON [DB].[name] = [C].[name]
			LEFT JOIN @last_backup [LB]
				ON [DB].[name] = [LB].[name]
		WHERE [C].[backup_check_enabled] = 1

	IF (SELECT COUNT(*) FROM @check_output WHERE [state] != 'OK') = 0
	BEGIN
		SELECT @backup_enabled = COUNT(*) FROM [checkmk].[configuration_database] WHERE [backup_check_enabled] = 1;
		SELECT @backup_disabled = COUNT(*) FROM [checkmk].[configuration_database] WHERE [backup_check_enabled] = 0;

		INSERT INTO @check_output VALUES('NA', 'Monitoring databases for backup(s)'
			+ '; enabled=' + CAST(@backup_enabled AS VARCHAR(8)) 
			+ '; disabled=' + CAST(@backup_disabled AS VARCHAR(8)));
	END

	SELECT [state], [message] FROM @check_output WHERE [state] != 'OK';
END
