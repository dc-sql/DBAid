CREATE PROCEDURE [checkmk].[inventory_agentjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	/* Inventory check_job */
	MERGE INTO [checkmk].[configuration_agentjob] AS [Target]
	USING(SELECT [J].[job_id]
			,[J].[name]
		FROM [msdb].[dbo].[sysjobs] [J]) AS [Source]
	ON [Target].[name] = [Source].[name]
	WHEN MATCHED THEN
		UPDATE SET [Target].[job_id] = [Source].[job_id]
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([job_id],
				[name])
		VALUES ([Source].[job_id],
				[Source].[name])
	WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END
