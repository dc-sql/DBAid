/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[backup]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_config TABLE([config_name] NVARCHAR(128), [item_name] NVARCHAR(128), [check_value] SQL_VARIANT, [check_change_alert] VARCHAR(10));
	DECLARE @check_output TABLE([message] NVARCHAR(4000),[state] NVARCHAR(8));

	DECLARE @preferred_backup TABLE ([db_name] NVARCHAR(128), [preferred_backup] BIT);
	DECLARE @full_backup INT, @diff_backup INT, @log_backup INT, @major_version INT, @cluster NVARCHAR(128);
	
	SELECT @major_version = [major] FROM [get].[product_version]();

	INSERT INTO @check_config
		SELECT [config_name]
			,[item_name]
			,[check_value]
			,[check_change_alert]
		FROM [get].[check_configuration](OBJECT_NAME(@@PROCID), NULL, NULL);

	SELECT @full_backup=COUNT(*) 
	FROM [get].[check_configuration](OBJECT_NAME(@@PROCID), N'full_backup_frequency_hour', NULL) 
	WHERE [check_value] IS NOT NULL

	SELECT @diff_backup=COUNT(*) 
	FROM [get].[check_configuration](OBJECT_NAME(@@PROCID), N'diff_backup_frequency_hour', NULL) 
	WHERE [check_value] IS NOT NULL

	SELECT @log_backup=COUNT(*) 
	FROM [get].[check_configuration](OBJECT_NAME(@@PROCID), N'log_backup_frequency_hour', NULL) 
	WHERE [check_value] IS NOT NULL

	IF @major_version >= 11
	BEGIN
		INSERT INTO @preferred_backup
		EXEC sp_executesql N'SELECT [name],[sys].[fn_hadr_backup_is_preferred_replica]([name]) AS [preferred_backup] FROM [sys].[databases]'
	END
	ELSE
	BEGIN
		;WITH [Backup]
		AS (
			SELECT [CC].[config_name] 
				,[CC].[ci_name]
				,CAST([CC].[check_value] AS NUMERIC(5,2)) AS [check_value]
				,[CC].[check_change_alert]
				,[DB].[create_date] AS [db_create_date]
				,[B].[backup_finish_date]
				,[B].[type]
				,ROW_NUMBER() OVER (PARTITION BY [CC].[config_name], [CC].[ci_name] ORDER BY [B].[backup_finish_date] DESC) AS [row]
			FROM [sys].[databases] [DB] 
				LEFT JOIN [msdb].[dbo].[backupset] [B]
					ON [DB].[name] = [B].[database_name]
				LEFT JOIN @check_config [CC]
					ON CASE [B].[type]
						WHEN 'D' THEN 'full_backup_frequency_hour'
						WHEN 'I' THEN 'diff_backup_frequency_hour'
						WHEN 'L' THEN 'log_backup_frequency_hour' END = [CC].[config_name] COLLATE Database_Default
					AND [B].[database_name] = [CC].[ci_name] COLLATE Database_Default
				OUTER APPLY(SELECT [preferred_backup] FROM @preferred_backup WHERE [db_name] = [CC].[ci_name]) AS [AG_backup]
			WHERE [CC].[check_value] IS NOT NULL
				AND ([AG_backup].[preferred_backup] = 1 OR [AG_backup].[preferred_backup] IS NULL)
		)
		INSERT INTO @check_output
			SELECT 'database=' 
				+ QUOTENAME([ci_name])
				+ '; last_backup=' 
				+ ISNULL(REPLACE(CONVERT(NVARCHAR(20), [backup_finish_date], 120), N' ', N'T'), N'NEVER')
				+ '; '
				+ [config_name] 
				+ '='
				+ CAST([check_value] AS VARCHAR(10)) AS [message]
				,[check_change_alert] AS [state]
			FROM [Backup]
			WHERE [row] = 1
				AND (DATEDIFF(MINUTE, ISNULL([backup_finish_date], [db_create_date]), GETDATE())/60.00) >= [check_value]
			ORDER BY [backup_finish_date] DESC
	END

	IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output VALUES('Monitoring database backup(s) for full=' 
			+ CAST(@full_backup AS VARCHAR(3)) + N'; diff=' 
			+ CAST(@diff_backup AS VARCHAR(3)) + N'; tlog=' 
			+ CAST(@log_backup AS VARCHAR(3)), N'NA');

	SELECT [message], [state] 
	FROM @check_output;
END
