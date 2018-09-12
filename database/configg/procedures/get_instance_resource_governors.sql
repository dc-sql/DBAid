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
	DECLARE @sql NVARCHAR(MAX);

	SELECT 'Instance' AS [heading], 'Resource Governor' AS [subheading], '' AS [comment]

	SELECT @sql = 'SELECT
	(SELECT [is_enabled] FROM [master].[sys].[resource_governor_configuration]) AS [is_enabled], CAST((' 
	+ (SELECT 'SELECT ' + STUFF(CAST((SELECT ',' + [name] + ' AS [@' + [name] + ']'  AS [text()]
		FROM [master].[sys].[all_columns] 
		WHERE [object_id] = OBJECT_ID(N'sys.resource_governor_resource_pools')
		FOR XML PATH('')) AS VARCHAR(MAX)), 1, 1, ''))
	+ ' FROM sys.resource_governor_resource_pools FOR XML PATH(''row''), ROOT(''table'')' + ') AS XML) AS [resource_governor_resource_pools], CAST((' 
	+ (SELECT 'SELECT ' + STUFF(CAST((SELECT ',' + [name] + ' AS [@' + [name] + ']'  AS [text()]
		FROM [master].[sys].[all_columns] 
		WHERE [object_id] = OBJECT_ID(N'sys.resource_governor_workload_groups')
		FOR XML PATH('')) AS VARCHAR(MAX)), 1, 1, ''))
	+ ' FROM sys.resource_governor_workload_groups FOR XML PATH(''row''), ROOT(''table'')' + ') AS XML) AS [resource_governor_workload_groups]
			,CAST((SELECT
					[definition] 
				FROM [master].[sys].[sql_modules] [SM]
					INNER JOIN
						[master].[sys].[resource_governor_configuration] [RC]
							ON [SM].[object_id] = [RC].[classifier_function_id]
								FOR XML PATH(''Classifier'')) AS XML) AS [Classifier]'

	IF ((SELECT SUBSTRING(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR), 1, CHARINDEX('.',  CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR)) - 1)) != 9)
	BEGIN
		EXEC sp_executesql @stmt = @sql
	END
END
