CREATE PROCEDURE [checkmk].[inventory_database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_database state_desc */
	MERGE INTO [checkmk].[configuration_database] AS [Target]
	USING(SELECT [D].[name] FROM sys.databases [D]) AS [Source]
	ON [Target].[name] = [Source].[name]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([name]) VALUES ([Source].[name])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END

