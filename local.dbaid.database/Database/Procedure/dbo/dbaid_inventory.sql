/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [dbo].[dbaid_inventory]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	/* Inventory procedure_list */
	MERGE INTO [setting].[procedure_list] AS [Target]
	USING (SELECT [O].[object_id] AS [procedure_id]
			,OBJECT_SCHEMA_NAME([O].[object_id]) AS [schema_name]
			,OBJECT_NAME([O].[object_id]) AS [procedure_name]
			,1 AS [is_enabled]
		FROM [sys].[objects] [O]
		WHERE [type] = 'P' 
		AND OBJECT_SCHEMA_NAME([object_id]) IN (N'log',N'report',N'check',N'chart',N'configg')) AS [Source]
	ON [Target].[schema_name] = [Source].[schema_name]
		AND [Target].[procedure_name] = [Source].[procedure_name]
	WHEN MATCHED THEN 
		UPDATE SET [Target].[procedure_id] = [Source].[procedure_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([procedure_id],[schema_name],[procedure_name],[is_enabled])
		VALUES ([Source].[procedure_id],[Source].[schema_name],[Source].[procedure_name],[Source].[is_enabled])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	/* Inventory check_database */
	MERGE INTO [setting].[check_database] AS [Target]
	USING(SELECT [D].[database_id]
			,[D].[name] AS [db_name]
			,(SELECT TOP(1) CAST([value] AS TINYINT) FROM [setting].[static_parameters] WHERE [name] = N'DEFAULT_CAP_WARN_PERCENT') AS [capacity_warning_percent_free]
			,(SELECT TOP(1) CAST([value] AS TINYINT) FROM [setting].[static_parameters] WHERE [name] = N'DEFAULT_CAP_CRIT_PERCENT') AS [capacity_critical_percent_free]
			,[M].[mirroring_role_desc] AS [mirroring_role]
			,CASE WHEN LOWER([D].[name]) IN (N'tempdb') THEN 0
				ELSE (SELECT TOP(1) CAST([value] AS NVARCHAR(8)) 
					FROM [setting].[static_parameters] 
					WHERE [name] = N'DEFAULT_BACKUP_FREQ') END AS [backup_frequency_hours]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) 
				FROM [setting].[static_parameters] 
				WHERE [name] = 'DEFAULT_BACKUP_STATE') AS [backup_state_alert]
			,CASE WHEN LOWER([D].[name]) IN (N'tempdb') THEN 0
				ELSE (SELECT TOP(1) CAST([value] AS NVARCHAR(8)) 
					FROM [setting].[static_parameters] 
					WHERE [name] = N'DEFAULT_CHECKDB_FREQ') END AS [checkdb_frequency_hours]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) 
				FROM [setting].[static_parameters] 
				WHERE [name] = 'DEFAULT_CHECKDB_STATE') AS [checkdb_state_alert]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) 
				FROM [setting].[static_parameters] 
				WHERE [name] = N'DEFAULT_DB_STATE') AS [change_state_alert]
			,1 AS [is_enabled]
		FROM sys.databases [D]
			LEFT JOIN sys.database_mirroring [M]
				ON [D].[database_id] = [M].[database_id]) AS [Source]
	ON [Target].[db_name] = [Source].[db_name]
	WHEN MATCHED THEN
		UPDATE SET [Target].[database_id] = [Source].[database_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([database_id]
			,[db_name]
			,[capacity_warning_percent_free]
			,[capacity_critical_percent_free]
			,[mirroring_role]
			,[backup_frequency_hours]
			,[checkdb_frequency_hours]
			,[change_state_alert]
			,[is_enabled])
		VALUES ([Source].[database_id]
			,[Source].[db_name]
			,[Source].[capacity_warning_percent_free]
			,[Source].[capacity_critical_percent_free]
			,[Source].[mirroring_role]
			,[Source].[backup_frequency_hours]
			,[Source].[checkdb_frequency_hours]
			,[Source].[change_state_alert]
			,[Source].[is_enabled])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	/* Inventory check_job */
	MERGE INTO [setting].[check_job] AS [Target]
	USING(SELECT [J].[job_id]
			,[J].[name] AS [job_name]
			,(SELECT TOP(1) CAST([value] AS SMALLINT) FROM [setting].[static_parameters] WHERE [name] = N'DEFAULT_JOB_MAX_MIN') AS [max_exec_time_min]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [setting].[static_parameters] WHERE [name] = N'DEFAULT_JOB_STATE') AS [change_state_alert]
			,(SELECT TOP(1) CAST([value] AS BIT) FROM [setting].[static_parameters] WHERE [name] = N'DEFAULT_JOB_ENABLED') AS [is_enabled]
		FROM [msdb].[dbo].[sysjobs] [J]) AS [Source]
	ON [Target].[job_name] = [Source].[job_name]
	WHEN MATCHED THEN
		UPDATE SET [Target].[job_id] = [Source].[job_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([job_id],[job_name],[max_exec_time_min],[change_state_alert],[is_enabled])
		VALUES ([Source].[job_id],[Source].[job_name],[Source].[max_exec_time_min],[Source].[change_state_alert],[Source].[is_enabled])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	/* Inventory check_alwayson */
	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN
		INSERT INTO [setting].[check_alwayson]([ag_id],[ag_name],[ag_state_alert],[ag_role],[ag_role_alert])
		EXEC [dbo].[sp_executesql] @stmt = N'SELECT [AG].[group_id]
				,[AG].[name] 
				,(SELECT CAST([value] AS NVARCHAR(8)) FROM [setting].[static_parameters] WHERE [name] = ''DEFAULT_ALWAYSON_STATE'') AS [ag_state_alert]
				,[RS].[role_desc]
				,(SELECT CAST([value] AS NVARCHAR(8)) FROM [setting].[static_parameters] WHERE [name] = ''DEFAULT_ALWAYSON_ROLE'') AS [ag_role_alert]
			FROM [master].[sys].[availability_groups] [AG]
			INNER JOIN [master].[sys].[dm_hadr_availability_replica_cluster_states] [RCS] 
				ON [RCS].[group_id] = [AG].[group_id] 
					AND [RCS].[replica_server_name] = @@SERVERNAME
			INNER JOIN  [master].[sys].[dm_hadr_availability_replica_states] [RS] 
				ON [RS].[group_id] = [AG].[group_id]
					AND [RS].[replica_id] = [RCS].[replica_id]
					AND [AG].[group_id] NOT IN (SELECT [ag_id] FROM [setting].[check_alwayson])';

		EXEC [dbo].[sp_executesql] @stmt=N'DELETE FROM [setting].[check_alwayson] WHERE [ag_id] NOT IN (SELECT [group_id] FROM [master].[sys].[availability_groups])';
	END

	REVERT;
	REVERT;
END
GO

