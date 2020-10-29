/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[inventory_agentjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = '_dbaid_sa';

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
	
	REVERT;
END
