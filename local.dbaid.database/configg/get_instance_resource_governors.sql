/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_instance_resource_governors]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF ((SELECT SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR), 1, CHARINDEX('.',  CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR)) - 1)) != 9)
	BEGIN
		EXEC sp_executesql @stmt = N'SELECT
		(SELECT [is_enabled] FROM [master].[sys].[resource_governor_configuration]) AS [is_enabled] 
		,CAST((SELECT *	FROM [master].[sys].[resource_governor_resource_pools] FOR XML PATH(''row''), ROOT(''table'')) AS XML) AS [resource_governor_resource_pools]
		,CAST((SELECT *	FROM [master].[sys].[resource_governor_workload_groups] FOR XML PATH(''row''), ROOT(''table'')) AS XML) AS [resource_governor_workload_groups]
		,CAST((SELECT
				[definition] 
			FROM [master].[sys].[sql_modules] [SM]
				INNER JOIN
					[master].[sys].[resource_governor_configuration] [RC]
						ON [SM].[object_id] = [RC].[classifier_function_id]
							FOR XML PATH(''Classifier'')) AS XML) AS [Classifier]'
	END
END
