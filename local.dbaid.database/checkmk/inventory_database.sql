CREATE PROCEDURE [checkmk].[inventory_database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_database state_desc */
	MERGE INTO [checkmk].[configuration_database] AS [Target]
	USING(SELECT [D].[database_id]
			,[D].[name]
		FROM sys.databases [D]) AS [Source]
	ON [Target].[name] = [Source].[name]
	WHEN MATCHED THEN
		UPDATE SET [Target].[database_id] = [Source].[database_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([database_id],
				[name])
		VALUES ([Source].[database_id]
			,[Source].[name])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END

