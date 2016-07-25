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

	DECLARE @to_backup INT;
	DECLARE @not_backup INT;
	DECLARE @version NUMERIC(18,10) 

	SET @version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

	IF @version >= 11 AND SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN

		EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

		EXEC [dbo].[sp_executesql] @stmt = N'
		DECLARE @check TABLE([message] NVARCHAR(4000)
					,[state] NVARCHAR(8));

		DECLARE @to_backup INT;
		DECLARE @not_backup INT;

		SELECT @to_backup=COUNT(*) FROM [dbo].[config_database] [D]
		LEFT JOIN (SELECT [AG].[name], 
						[DS].[database_id], 
						[AG].[automated_backup_preference],
						[RS].[Role] FROM  [master].[sys].[dm_hadr_availability_replica_states] [RS]
						INNER JOIN [master].[sys].[dm_hadr_database_replica_states] [DS]
							ON [RS].[group_id] = [DS].[group_id]
								AND [RS].[is_local] = 1  AND [DS].[is_local] = 1
						INNER JOIN [master].[sys].[availability_groups] [AG]
							ON [AG].[group_id] = [RS].[group_id]) AS [table] 
								ON [table].[database_id] = [D].[database_id]
		WHERE [backup_frequency_hours] > 0 
			AND LOWER([db_name]) NOT IN (N''tempdb'')
			AND ISNULL([table].[automated_backup_preference],0) = 0
			AND ISNULL([table].[Role],1) = 1

		SELECT @not_backup=COUNT(*) - @to_backup FROM [dbo].[config_database] [D] WHERE LOWER([db_name]) NOT IN (N''tempdb'')	

				;WITH Backups
		AS
		(
			SELECT ROW_NUMBER() OVER (PARTITION BY [D].[name] ORDER BY [B].[backup_finish_date] DESC) AS [row]
				,[D].[database_id]
				,[B].[backup_finish_date]
				,[B].[type]
				,[D].[create_date]
			FROM [sys].[databases] [D]
				LEFT JOIN [msdb].[dbo].[backupset] [B]
					ON [D].[name] = [B].[database_name]
						AND [B].[type] IN (''D'', ''I'')
						AND [B].[is_copy_only] = 0
		)
		INSERT INTO @check
		SELECT N''database='' 
			+ QUOTENAME([D].[db_name])
			+ N''; last_backup='' 
			+ ISNULL(REPLACE(CONVERT(NVARCHAR(20), [B].[backup_finish_date], 120), N'' '', N''T''), N''NEVER'')
			+ N''; type='' 
			+ CASE [type] WHEN ''D'' THEN ''FULL'' WHEN ''I'' THEN ''DIFFERENTIAL'' ELSE ''UNKNOWN'' END
			+ N''; backups_missed='' 
			+ ISNULL(CAST(CAST(DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) / [D].[backup_frequency_hours] AS INT) AS VARCHAR(5)), ''ALL'')
			,[S].[state]
		FROM Backups [B]
			INNER JOIN [dbo].[config_database] [D]
				ON [B].[database_id] = [D].[database_id]
			LEFT JOIN (SELECT [AG].[name], 
						[DS].[database_id], 
						[AG].[automated_backup_preference],
						[RS].[Role] FROM  [master].[sys].[dm_hadr_availability_replica_states] [RS]
						INNER JOIN [master].[sys].[dm_hadr_database_replica_states] [DS]
							ON [RS].[group_id] = [DS].[group_id]
								AND [RS].[is_local] = 1  AND [DS].[is_local] = 1
						INNER JOIN [master].[sys].[availability_groups] [AG]
							ON [AG].[group_id] = [RS].[group_id]) AS [table] 
								ON [table].[database_id] = [D].[database_id] 
			CROSS APPLY (SELECT CASE WHEN ([B].[backup_finish_date] IS NULL OR DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) > ([D].[backup_frequency_hours])) THEN [D].[backup_state_alert] ELSE N''OK'' END AS [state]) [S]
		WHERE [B].[row] = 1
			AND [D].[backup_frequency_hours] > 0
			AND DATEDIFF(HOUR, [B].[create_date], GETDATE()) > [D].[backup_frequency_hours]
			AND LOWER([D].[db_name]) NOT IN (N''tempdb'')
			AND ISNULL([table].[automated_backup_preference],0) = 0
			AND ISNULL([table].[Role],1) = 1
			AND [S].[state] NOT IN (N''OK'')
		ORDER BY [D].[db_name]
		
		IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(CAST(@to_backup AS NVARCHAR(10)) + N'' database(s) monitored, '' + CAST(@not_backup AS NVARCHAR(10)) + N'' database(s) opted-out'', N''NA'');

		SELECT [message], [state] 
		FROM @check;'

		REVERT;
		REVERT;
	END
	ELSE
	BEGIN
		SELECT @to_backup=COUNT(*) FROM [dbo].[config_database] WHERE [backup_frequency_hours] > 0 AND LOWER([db_name]) NOT IN (N'tempdb')
		SELECT @not_backup=COUNT(*) FROM [dbo].[config_database] WHERE [backup_frequency_hours] = 0 AND LOWER([db_name]) NOT IN (N'tempdb')

		;WITH Backups
		AS
		(
			SELECT ROW_NUMBER() OVER (PARTITION BY [D].[name] ORDER BY [B].[backup_finish_date] DESC) AS [row]
				,[D].[database_id]
				,[B].[backup_finish_date]
				,[B].[type]
				,[D].[create_date]
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
				+ ISNULL(CAST(CAST(DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) / [D].[backup_frequency_hours] AS INT) AS VARCHAR(5)), 'ALL')
			,[S].[state]
		FROM Backups [B]
			INNER JOIN [dbo].[config_database] [D]
				ON [B].[database_id] = [D].[database_id]
			CROSS APPLY (SELECT CASE WHEN ([B].[backup_finish_date] IS NULL OR DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) > ([D].[backup_frequency_hours])) THEN [D].[backup_state_alert] ELSE N'OK' END AS [state]) [S]
		WHERE [B].[row] = 1
			AND [D].[backup_frequency_hours] > 0
			AND DATEDIFF(HOUR, [B].[create_date], GETDATE()) > [D].[backup_frequency_hours]
			AND LOWER([D].[db_name]) NOT IN (N'tempdb')
			AND [S].[state] NOT IN (N'OK')
		ORDER BY [D].[db_name]
	
		IF (SELECT COUNT(*) FROM @check) < 1
			INSERT INTO @check VALUES(CAST(@to_backup AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@not_backup AS NVARCHAR(10)) + N' database(s) opted-out', N'NA');

		SELECT [message], [state] 
		FROM @check;
	END
END