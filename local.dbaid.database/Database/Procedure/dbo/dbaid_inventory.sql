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
		FROM [sys].[objects] [O]
		WHERE [type] = 'P' 
		AND OBJECT_SCHEMA_NAME([object_id]) IN (N'log',N'check',N'chart',N'configg')) AS [Source]
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

	/* Inventory check_database state_desc */
	MERGE INTO [setting].[check_database] AS [Target]
	USING(SELECT 'database' AS [object_name]
		,[D].[name] AS [item_name]
		,'state_desc' AS [column_name]
		,[D].[state_desc] AS [column_value]
		,'critical' AS [change_alert]
	FROM sys.databases [D]) AS [Source]
	ON [Target].[object_name] = [Source].[object_name]
		AND [Target].[item_name] = [Source].[item_name]
		AND [Target].[column_name] = [Source].[column_name]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([object_name],
				[item_name],
				[column_name],
				[column_value],
				[change_alert])
		VALUES ([Source].[object_name]
			,[Source].[item_name]
			,[Source].[column_name]
			,[Source].[column_value]
			,[Source].[change_alert])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;

	--/* Inventory check_job */
	--MERGE INTO [setting].[check_job] AS [Target]
	--USING(SELECT [J].[job_id]
	--		,[J].[name] AS [job_name]
	--	FROM [msdb].[dbo].[sysjobs] [J]) AS [Source]
	--ON [Target].[job_name] = [Source].[job_name]
	--WHEN MATCHED THEN
	--	UPDATE SET [Target].[job_id] = [Source].[job_id]
	--WHEN NOT MATCHED BY TARGET THEN
	--	INSERT ([job_id],
	--			[job_name])
	--	VALUES ([Source].[job_id],
	--			[Source].[job_name])
	--WHEN NOT MATCHED BY SOURCE THEN
	--	DELETE;

	--/* Inventory check_alwayson */
	--IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	--BEGIN
	--	EXEC [dbo].[sp_executesql] @stmt = N'MERGE INTO [setting].[check_alwayson] AS [Target]
	--		USING(SELECT [AG].[group_id] AS [availability_group_id]
	--			,[AG].[name] AS [availability_group_name]
	--			,[RS].[role_desc] AS [expected_node_role]
	--		FROM [master].[sys].[availability_groups] [AG]
	--			INNER JOIN [master].[sys].[dm_hadr_availability_replica_cluster_states] [RCS] 
	--				ON [RCS].[group_id] = [AG].[group_id] 
	--					AND [RCS].[replica_server_name] = @@SERVERNAME
	--			INNER JOIN  [master].[sys].[dm_hadr_availability_replica_states] [RS] 
	--				ON [RS].[group_id] = [AG].[group_id]
	--					AND [RS].[replica_id] = [RCS].[replica_id]) AS [Source]
	--		ON [Target].[availability_group_name] = [Source].[availability_group_name]
	--		WHEN MATCHED THEN
	--			UPDATE SET [Target].[availability_group_id] = [Source].[availability_group_id]
	--		WHEN NOT MATCHED BY TARGET THEN
	--			INSERT ([availability_group_id],
	--					[availability_group_name],
	--					[expected_node_role])
	--			VALUES ([Source].[availability_group_id],
	--					[Source].[availability_group_name],
	--					[Source].[expected_node_role])
	--		WHEN NOT MATCHED BY SOURCE THEN
	--			DELETE;';
	--END

	REVERT;
	REVERT;
END
GO

