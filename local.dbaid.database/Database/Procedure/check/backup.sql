/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[backup]
WITH ENCRYPTION
AS
BEGIN
SET NOCOUNT ON;

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	DECLARE @to_backup INT, @not_backup INT, @major_version INT, @cluster NVARCHAR(128);

	SELECT @major_version = [major] FROM [get].[product_version]();

	IF @major_version >= 11
		EXEC sp_executesql N'SELECT @out=[cluster_name] FROM [sys].[dm_hadr_cluster]', N'@out NVARCHAR(128) OUTPUT', @out = @cluster;

	IF @major_version >= 11 AND @cluster IS NOT NULL
	BEGIN
		EXEC sp_executesql N'SELECT @out=COUNT(*) FROM [setting].[check_database] [D]
						CROSS APPLY(SELECT [sys].[fn_hadr_backup_is_preferred_replica]([D].[db_name]) AS [IsPreferredBackupReplicaNow]) AS [AG_backup]
							WHERE [check_backup_since_hour] > 0 AND LOWER([db_name]) NOT IN (N''tempdb'') AND [AG_backup].[IsPreferredBackupReplicaNow] > 0', N'@out NVARCHAR(128) OUTPUT', @out = @to_backup;

		EXEC sp_executesql N'SELECT @out=COUNT(*) FROM [setting].[check_database] [D] 
						CROSS APPLY(SELECT [sys].[fn_hadr_backup_is_preferred_replica]([D].[db_name]) AS [IsPreferredBackupReplicaNow]) AS [AG_backup]
							WHERE [check_backup_since_hour] = 0 AND LOWER([db_name]) NOT IN (N''tempdb'') OR [AG_backup].[IsPreferredBackupReplicaNow] = 0', N'@out NVARCHAR(128) OUTPUT', @out = @not_backup;

		EXEC sp_executesql N';WITH Backups AS (
			SELECT ROW_NUMBER() OVER (PARTITION BY [D].[name] ORDER BY [B].[backup_finish_date] DESC) AS [row]
				,[D].[database_id]
				,[B].[backup_finish_date]
				,[B].[type]
				,[AG_backup].[IsPreferredBackupReplicaNow]
			FROM [sys].[databases] [D]
				LEFT JOIN [msdb].[dbo].[backupset] [B]
					ON [D].[name] = [B].[database_name]
						AND [B].[type] IN (''D'',''I'')
						AND [B].[is_copy_only] = 0
				CROSS APPLY(SELECT [sys].[fn_hadr_backup_is_preferred_replica]([D].[name]) AS [IsPreferredBackupReplicaNow]) AS [AG_backup]
			)
			INSERT INTO @check
			SELECT N''database='' 
					+ QUOTENAME([D].[db_name])
					+ N''; last_backup=''
					+ ISNULL(REPLACE(CONVERT(NVARCHAR(20), [B].[backup_finish_date], 120), N'' '', N''T''), N''NEVER'')
					+ N''; type='' 
					+ CASE [type] WHEN ''D'' THEN ''FULL'' WHEN ''I'' THEN ''DIFFERENTIAL'' ELSE ''UNKNOWN'' END
					+ N''; backups_missed='' 
					+ ISNULL(CAST(CAST(DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) / [D].[check_backup_since_hour] AS INT) AS VARCHAR(5)), ''ALL'')
				,[S].[state]
			FROM Backups [B]
				INNER JOIN [setting].[check_database] [D]
					ON [B].[database_id] = [D].[database_id]
				CROSS APPLY (SELECT CASE WHEN ([B].[backup_finish_date] IS NULL OR DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) > ([D].[check_backup_since_hour])) THEN [D].[check_backup_state] ELSE N''OK'' END AS [state]) [S]
			WHERE [B].[row] = 1
				AND [D].[check_backup_since_hour] > 0
				AND LOWER([D].[db_name]) NOT IN (N''tempdb'')
				AND [S].[state] NOT IN (N''OK'')
				AND [B].[IsPreferredBackupReplicaNow] = 1
			ORDER BY [D].[db_name]';
	END
	ELSE
	BEGIN
		SELECT @to_backup=COUNT(*) FROM [setting].[check_database] WHERE [check_backup_since_hour] > 0 AND LOWER([db_name]) NOT IN (N'tempdb')
		SELECT @not_backup=COUNT(*) FROM [setting].[check_database] WHERE [check_backup_since_hour] = 0 AND LOWER([db_name]) NOT IN (N'tempdb')

		;WITH Backups
		AS
		(
			SELECT ROW_NUMBER() OVER (PARTITION BY [D].[name] ORDER BY [B].[backup_finish_date] DESC) AS [row]
				,[D].[database_id]
				,[B].[backup_finish_date]
				,[B].[type]
			FROM [sys].[databases] [D]
				LEFT JOIN [msdb].[dbo].[backupset] [B]
					ON [D].[name] = [B].[database_name]
						AND [B].[type] IN ('D', 'I')
						AND [B].[is_copy_only] = 0
		)
		INSERT INTO @check
		SELECT N'database=' 
				+ QUOTENAME([D].[db_name])
				+ N'; last_backup=' 
				+ ISNULL(REPLACE(CONVERT(NVARCHAR(20), [B].[backup_finish_date], 120), N' ', N'T'), N'NEVER')
				+ N'; type=' 
				+ CASE [type] WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFFERENTIAL' ELSE 'UNKNOWN' END
				+ N'; backups_missed=' 
				+ ISNULL(CAST(CAST(DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) / [D].[check_backup_since_hour] AS INT) AS VARCHAR(5)), 'ALL')
			,[S].[state]
		FROM Backups [B]
			INNER JOIN [setting].[check_database] [D]
				ON [B].[database_id] = [D].[database_id]
			CROSS APPLY (SELECT CASE WHEN ([B].[backup_finish_date] IS NULL OR DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) > ([D].[check_backup_since_hour])) THEN [D].[check_backup_state] ELSE N'OK' END AS [state]) [S]
		WHERE [B].[row] = 1
			AND [D].[check_backup_since_hour] > 0
			AND LOWER([D].[db_name]) NOT IN (N'tempdb')
			AND [S].[state] NOT IN (N'OK')
		ORDER BY [D].[db_name]
	END
	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(CAST(@to_backup AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@not_backup AS NVARCHAR(10)) + N' database(s) opted-out', N'NA');

	SELECT [message], [state] 
	FROM @check;
END
