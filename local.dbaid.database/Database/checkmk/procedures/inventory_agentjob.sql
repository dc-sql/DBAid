/*



*/

CREATE PROCEDURE [checkmk].[inventory_agentjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_job */
	MERGE INTO [checkmk].[config_agentjob] AS [target]
	USING(SELECT [J].[name] FROM [msdb].[dbo].[sysjobs] [J]) AS [source]
	ON [target].[name] = [source].[name] COLLATE DATABASE_DEFAULT
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([name])	VALUES ([source].[name])
	WHEN MATCHED THEN
		UPDATE SET [target].[inventory_date] = GETDATE()
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END
