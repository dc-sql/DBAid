﻿/*
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
	DECLARE @tenant NVARCHAR(256);
  
	SELECT @tenant = CAST([value] AS nvarchar(256)) FROM [$(DatabaseName)].[dbo].[static_parameters] WHERE [name] = N'TENANT_NAME';

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	IF SERVERPROPERTY('IsHadrEnabled') = 1
	BEGIN
		EXEC [dbo].[sp_executesql] @stmt = N'
		DECLARE @check TABLE([message] NVARCHAR(4000)
					,[state] NVARCHAR(8));

		DECLARE @to_backup INT;
		DECLARE @not_backup INT;

		DECLARE @tenant NVARCHAR(256);

		SELECT @tenant = CAST([value] AS nvarchar(256)) FROM [_dbaid].[dbo].[static_parameters] WHERE [name] = N''TENANT_NAME'';

		DECLARE @ag_table AS TABLE (
			[ag_id] UNIQUEIDENTIFIER,
			[name] SYSNAME, 
			[database_id] INT, 
			[automated_backup_preference] TINYINT,
			[role] TINYINT
		);

		INSERT into @ag_table
		SELECT [AG].[group_id],
			[AG].[name], 
			[DS].[database_id], 
			[AG].[automated_backup_preference],
			[RS].[role] 
		FROM [master].[sys].[dm_hadr_availability_replica_states] [RS]
			INNER JOIN [master].[sys].[dm_hadr_database_replica_states] [DS]
				ON [RS].[group_id] = [DS].[group_id]
				AND [RS].[is_local] = 1  
				AND [DS].[is_local] = 1
			INNER JOIN [master].[sys].[availability_groups] [AG]
				ON [AG].[group_id] = [RS].[group_id]

		SELECT @to_backup=COUNT(*) FROM [dbo].[config_database] [D]
		LEFT JOIN (SELECT [AG].[name], 
						[DS].[database_id], 
						[AG].[automated_backup_preference],
						[RS].[role] 
					FROM  [master].[sys].[dm_hadr_availability_replica_states] [RS]
						INNER JOIN [master].[sys].[dm_hadr_database_replica_states] [DS]
							ON [RS].[group_id] = [DS].[group_id]
								AND [RS].[is_local] = 1  AND [DS].[is_local] = 1
						INNER JOIN [master].[sys].[availability_groups] [AG]
							ON [AG].[group_id] = [RS].[group_id]) AS [table] 
								ON [table].[database_id] = [D].[database_id]
		WHERE [backup_frequency_hours] > 0 
			AND LOWER([db_name]) NOT IN (N''tempdb'')
			AND [is_enabled] = 1
			AND ISNULL([table].[automated_backup_preference],0) = 0
			AND ISNULL([table].[role],1) = 1

		SELECT @not_backup=COUNT(*) - @to_backup FROM [dbo].[config_database] [D] WHERE LOWER([db_name]) NOT IN (N''tempdb'') OR [is_enabled] = 0	

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
			WHERE [D].[state] = 0
				AND [D].[is_in_standby] = 0
		)
		INSERT INTO @check
		SELECT @tenant
			+ N'','' + CAST(SERVERPROPERTY(''MachineName'') AS sysname)
			+ N''#'' + ISNULL(CAST(SERVERPROPERTY(''InstanceName'') AS sysname), N''MSSQLSERVER'')
			+ N''#'' + [D].[db_name]
			+ N'','' + ISNULL(CONVERT(NVARCHAR(20), [B].[backup_finish_date], 23), N''1900-01-01'')
			+ N'','' + CASE [type] WHEN ''D'' THEN ''FULL'' WHEN ''I'' THEN ''DIFFERENTIAL'' ELSE ''UNKNOWN'' END
			,[S].[state]
		FROM Backups [B]
			INNER JOIN [$(DatabaseName)].[dbo].[config_database] [D]
				ON [B].[database_id] = [D].[database_id]
			LEFT JOIN @ag_table AS [AGT]
				ON [AGT].[database_id] = [D].[database_id] 
			LEFT JOIN [$(DatabaseName)].[dbo].[config_alwayson] [ca]
				ON [AGT].[ag_id] = [ca].[ag_id]
			CROSS APPLY (SELECT CASE WHEN ([B].[backup_finish_date] IS NULL OR DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) > ([D].[backup_frequency_hours])) THEN [D].[backup_state_alert] ELSE N''OK'' END AS [state]) [S]
		WHERE [B].[row] = 1
			AND [D].[backup_frequency_hours] > 0
			/* AND DATEDIFF(HOUR, [B].[create_date], GETDATE()) > [D].[backup_frequency_hours] */
			AND LOWER([D].[db_name]) NOT IN (N''tempdb'')
			AND ISNULL([AGT].[automated_backup_preference],0) = 0
			AND ISNULL([AGT].[role],1) = 1
			AND ((DATEDIFF(HOUR, [ca].[ag_role_change_datetime], GETDATE()) > [D].[backup_frequency_hours]) OR ([ca].[ag_role_change_datetime] IS NULL))
			/* AND [S].[state] NOT IN (N''OK'') */
			AND [D].[is_enabled] = 1
		ORDER BY [D].[db_name]

		IF (SELECT COUNT(*) FROM @check) < 1
			INSERT INTO @check VALUES(CAST(@to_backup AS NVARCHAR(10)) + N'' database(s) monitored, '' + CAST(@not_backup AS NVARCHAR(10)) + N'' database(s) opted-out'', N''NA'');

		SELECT [message], [state] 
		FROM @check;'
	END
	ELSE
	BEGIN
		SELECT @to_backup=COUNT(*) FROM [$(DatabaseName)].[dbo].[config_database] WHERE [backup_frequency_hours] > 0 AND LOWER([db_name]) NOT IN (N'tempdb') AND [is_enabled] = 1
		SELECT @not_backup=COUNT(*) FROM [$(DatabaseName)].[dbo].[config_database] WHERE [backup_frequency_hours] = 0 AND LOWER([db_name]) NOT IN (N'tempdb') OR [is_enabled] = 0

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
			WHERE [D].[state] = 0
				AND [D].[is_in_standby] = 0
		)
		/* Using # as separator for ServerName\InstanceName\DatabaseName as an instance or database with [lower case?] "n" as first character
			 leads to a "\n" combination that Checkmk interprets as a newline character. Does not seem to be possible to escape this combination
			 to stop it happening.
		*/
		INSERT INTO @check
		SELECT @tenant
				+ N',' + CAST(SERVERPROPERTY('MachineName') AS sysname) 
				+ N'#' + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS sysname), N'MSSQLSERVER')
				+ N'#' + [D].[db_name]
				+ N',' + ISNULL(CONVERT(NVARCHAR(20), [B].[backup_finish_date], 23), N'1900-01-01')
				+ N',' + CASE [type] WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFFERENTIAL' ELSE 'UNKNOWN' END
				,[S].[state]
		FROM Backups [B]
			INNER JOIN [$(DatabaseName)].[dbo].[config_database] [D]
				ON [B].[database_id] = [D].[database_id]
			CROSS APPLY (SELECT CASE WHEN ([B].[backup_finish_date] IS NULL OR DATEDIFF(HOUR, [B].[backup_finish_date], GETDATE()) > ([D].[backup_frequency_hours])) THEN [D].[backup_state_alert] ELSE N'OK' END AS [state]) [S]
		WHERE [B].[row] = 1
			AND [D].[backup_frequency_hours] > 0
			--AND DATEDIFF(HOUR, [B].[create_date], GETDATE()) > [D].[backup_frequency_hours]
			AND LOWER([D].[db_name]) NOT IN (N'tempdb')
			--AND [S].[state] NOT IN (N'OK')
			AND [D].[is_enabled] = 1
		ORDER BY [D].[db_name]

		IF (SELECT COUNT(*) FROM @check) < 1
			INSERT INTO @check VALUES(CAST(@to_backup AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@not_backup AS NVARCHAR(10)) + N' database(s) opted-out', N'NA');

		SELECT [message],[state] 
		FROM @check;
	END

	REVERT;
END


