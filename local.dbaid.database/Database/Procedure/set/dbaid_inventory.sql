/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [set].[dbaid_inventory]
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
		FROM [sys].[objects] [O]
		WHERE [type] = 'P' 
		AND OBJECT_SCHEMA_NAME([object_id]) IN (N'log',N'report',N'check',N'chart',N'configg')) AS [Source]
	ON [Target].[schema_name] = [Source].[schema_name]
		AND [Target].[procedure_name] = [Source].[procedure_name]
	WHEN MATCHED THEN 
		UPDATE SET [Target].[procedure_id] = [Source].[procedure_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([procedure_id],
				[schema_name],
				[procedure_name])
		VALUES ([Source].[procedure_id],
				[Source].[schema_name],
				[Source].[procedure_name])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	/* Inventory check_database */
	MERGE INTO [setting].[check_database] AS [Target]
	USING(SELECT [D].[database_id]
			,[D].[name] AS [db_name]
			,[M].[mirroring_role_desc] AS [mirroring_role]
		FROM sys.databases [D]
			LEFT JOIN sys.database_mirroring [M]
				ON [D].[database_id] = [M].[database_id]) AS [Source]
	ON [Target].[db_name] = [Source].[db_name]
	WHEN MATCHED THEN
		UPDATE SET [Target].[database_id] = [Source].[database_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([database_id],
				[db_name],
				[expected_mirror_role])
		VALUES ([Source].[database_id]
			,[Source].[db_name]
			,[Source].[mirroring_role])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	/* Inventory check_job */
	MERGE INTO [setting].[check_job] AS [Target]
	USING(SELECT [J].[job_id]
			,[J].[name] AS [job_name]
		FROM [msdb].[dbo].[sysjobs] [J]) AS [Source]
	ON [Target].[job_name] = [Source].[job_name]
	WHEN MATCHED THEN
		UPDATE SET [Target].[job_id] = [Source].[job_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([job_id],
				[job_name])
		VALUES ([Source].[job_id],
				[Source].[job_name])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	/* Inventory check_alwayson */
	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN
		EXEC [dbo].[sp_executesql] @stmt = N'MERGE INTO [setting].[check_alwayson] AS [Target]
			USING(SELECT [AG].[group_id] AS [availability_group_id]
				,[AG].[name] AS [availability_group_name]
				,[RS].[role_desc] AS [expected_node_role]
			FROM [master].[sys].[availability_groups] [AG]
				INNER JOIN [master].[sys].[dm_hadr_availability_replica_cluster_states] [RCS] 
					ON [RCS].[group_id] = [AG].[group_id] 
						AND [RCS].[replica_server_name] = @@SERVERNAME
				INNER JOIN  [master].[sys].[dm_hadr_availability_replica_states] [RS] 
					ON [RS].[group_id] = [AG].[group_id]
						AND [RS].[replica_id] = [RCS].[replica_id]) AS [Source]
			ON [Target].[availability_group_name] = [Source].[availability_group_name]
			WHEN MATCHED THEN
				UPDATE [Target].[availability_group_id] = [Source].[availability_group_id]
			WHEN NOT MATCHED BY TARGET THEN
				INSERT ([availability_group_id],
						[availability_group_name],
						[expected_node_role])
				VALUES ([Source].[availability_group_id],
						[Source].[availability_group_name],
						[Source].[expected_node_role])
			WHEN NOT MATCHED BY SOURCE THEN
				DELETE;';
	END

	REVERT;
	REVERT;
END
GO

