CREATE PROCEDURE [checkmk].[inventory_database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_database state_desc */
	MERGE INTO [checkmk].[config_database] [c]
	USING sys.databases [d]
	ON [c].[name] = [d].[name]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([name]) VALUES ([d].[name])
	WHEN MATCHED THEN
		UPDATE SET [c].[backup_check_tran_hour] = CASE WHEN [d].[recovery_model_desc] = 'SIMPLE' THEN NULL ELSE 1 END
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END

