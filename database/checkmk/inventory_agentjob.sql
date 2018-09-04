CREATE PROCEDURE [checkmk].[inventory_agentjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_job */
	MERGE INTO [checkmk].[config_agentjob] AS [Target]
	USING(SELECT [J].[name] FROM [msdb].[dbo].[sysjobs] [J]) AS [Source]
	ON [Target].[name] = [Source].[name]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([name])	VALUES ([Source].[name])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END
