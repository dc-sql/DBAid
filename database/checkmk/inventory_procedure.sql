/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[inventory_procedure]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory procedure_list */
	MERGE INTO [checkmk].[config_proc] AS [Target]
	USING (SELECT [O].[object_id] AS [proc_id]
			,OBJECT_SCHEMA_NAME([O].[object_id]) AS [schema]
			,OBJECT_NAME([O].[object_id]) AS [procedure]
		FROM [sys].[objects] [O]
		WHERE [type] = 'P' 
		AND OBJECT_SCHEMA_NAME([object_id]) IN (N'check',N'chart')) AS [Source]
	ON [Target].[schema] = [Source].[schema]
		AND [Target].[procedure] = [Source].[procedure]
	WHEN MATCHED THEN 
		UPDATE SET [Target].[proc_id] = [Source].[proc_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([proc_id],
				[schema],
				[procedure])
		VALUES ([Source].[proc_id],
				[Source].[schema],
				[Source].[procedure])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END
GO

