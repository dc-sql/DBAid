/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [maintenance].[check_config]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	/* Add new databases into check */
	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

		INSERT INTO [dbo].[config_database]
		SELECT [D].[database_id]
			,[D].[name]
			,(SELECT TOP(1) CAST([value] AS TINYINT) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CAP_WARN_PERCENT') AS [capacity_warning_percent_free]
			,(SELECT TOP(1) CAST([value] AS TINYINT) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CAP_CRIT_PERCENT') AS [capacity_critical_percent_free]
			,[M].[mirroring_role_desc]
			,CASE
				WHEN LOWER([D].[name]) IN (N'tempdb') THEN 0
				ELSE (SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_BACKUP_FREQ') 
			 END AS [backup_frequency_hours]
			 ,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = 'DEFAULT_BACKUP_STATE') AS [backup_state_alert]
			,CASE
				WHEN LOWER([D].[name]) IN (N'tempdb') THEN 0
				ELSE (SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CHECKDB_FREQ') 
			 END AS [checkdb_frequency_hours]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = 'DEFAULT_CHECKDB_STATE') AS [checkdb_state_alert]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_DB_STATE') AS [change_state_alert]
			,1 AS [is_enabled]
		FROM sys.databases [D]
			LEFT JOIN sys.database_mirroring [M]
				ON [D].[database_id] = [M].[database_id]
		WHERE [D].[database_id] NOT IN (SELECT [database_id] FROM [dbo].[config_database]);



	/* Add new agent jobs into check */
	INSERT INTO [dbo].[config_job]
		SELECT [J].[job_id]
			,[J].[name]
			,(SELECT TOP(1) CAST([value] AS SMALLINT) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_JOB_MAX_MIN') AS [max_exec_time_min]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_JOB_STATE') AS [change_state_alert]
			,(SELECT TOP(1) CAST([value] AS BIT) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_JOB_ENABLED') AS [is_enabled]
		FROM [msdb].[dbo].[sysjobs] [J]
		WHERE [job_id] NOT IN (SELECT [job_id] FROM [dbo].[config_job]);

	/* Add and remove new Availability groups into check */
	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
		BEGIN
			INSERT INTO [dbo].[config_alwayson]([ag_id],[ag_name],[ag_state_alert],[ag_role],[ag_role_alert])
			EXEC [dbo].[sp_executesql] @stmt = N'SELECT [AG].[group_id]
														,[AG].[name] 
														,(SELECT CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = ''DEFAULT_ALWAYSON_STATE'') AS [ag_state_alert]
														,[RS].[role_desc]
														,(SELECT CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = ''DEFAULT_ALWAYSON_ROLE'') AS [ag_role_alert]
													FROM [master].[sys].[availability_groups] [AG]
													INNER JOIN [master].[sys].[dm_hadr_availability_replica_cluster_states] [RCS] 
														ON [RCS].[group_id] = [AG].[group_id] 
															AND [RCS].[replica_server_name] = @@SERVERNAME
													INNER JOIN  [master].[sys].[dm_hadr_availability_replica_states] [RS] 
														ON [RS].[group_id] = [AG].[group_id]
															AND [RS].[replica_id] = [RCS].[replica_id]
															AND [AG].[group_id] NOT IN (SELECT [ag_id] FROM [dbo].[config_alwayson])';

			EXEC [dbo].[sp_executesql] @stmt=N'DELETE FROM [dbo].[config_alwayson]
												WHERE [ag_id] NOT IN (SELECT [group_id] FROM [master].[sys].[availability_groups])';
		END

	/* Update database names */
	UPDATE [dbo].[config_database]
	SET [db_name] = [D].[name]
	FROM sys.databases [D]
		INNER JOIN [dbo].[config_database] [C]
			ON [D].[database_id] = [C].[database_id];
	
	/* Update database mirroring role if previous was null */
	UPDATE [dbo].[config_database]
	SET [mirroring_role] = [M].[mirroring_role_desc]
	FROM [dbo].[config_database] [D]
		INNER JOIN sys.database_mirroring [M]
			ON [D].[database_id] = [M].[database_id]
		WHERE [M].[mirroring_role] IS NOT NULL 
			AND [D].[mirroring_role] IS NULL;

	/* Update job names */
	UPDATE [dbo].[config_job]
	SET [job_name] = [J].[name]
	FROM [msdb].[dbo].[sysjobs] [J]
		INNER JOIN [dbo].[config_job] [C]
			ON [J].[job_id] = [C].[job_id];

	/* Cleanup unused records */
	DELETE FROM [dbo].[config_database]
	WHERE [database_id] NOT IN (SELECT [database_id] FROM sys.databases);

	DELETE FROM [dbo].[config_job]
	WHERE [job_id] NOT IN (SELECT [job_id] FROM [msdb].[dbo].[sysjobs]);

	REVERT;
END



GO
GRANT EXECUTE
    ON OBJECT::[maintenance].[check_config] TO [monitor] AS [dbo];

