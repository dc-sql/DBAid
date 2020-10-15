/*



*/

CREATE PROCEDURE [checkmk].[inventory_database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_database state_desc */
	MERGE INTO [checkmk].[config_database] [target]
	USING sys.databases [source]
	ON [target].[name] = [source].[name] COLLATE DATABASE_DEFAULT
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([name]) VALUES ([source].[name])
	WHEN MATCHED THEN
		UPDATE SET [target].[inventory_date] = GETDATE()
	WHEN NOT MATCHED BY SOURCE AND [target].[inventory_date] < DATEADD(DAY, -7, GETDATE()) THEN
		DELETE;
END

