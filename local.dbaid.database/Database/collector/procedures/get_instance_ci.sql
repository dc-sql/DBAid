/*



*/

CREATE PROCEDURE [collector].[get_instance_ci]
(
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @flags TABLE([flag] INT, [enabled] BIT, [global] BIT, [session] INT);
	DECLARE @server_properties TABLE ([property] sysname); 

	INSERT INTO @flags EXEC('DBCC TRACESTATUS (-1) WITH NO_INFOMSGS');

	INSERT INTO @server_properties VALUES 
		('BuildClrVersion'),
		('Collation'),
		('CollationID'),
		('ComparisonStyle'),
		('ComputerNamePhysicalNetBIOS'),
		('Edition'),
		('EditionID'),
		('EngineEdition'),
		('HadrManagerStatus'),
		('InstanceDefaultDataPath'),
		('InstanceDefaultLogPath'),
		('InstanceName'),
		('IsAdvancedAnalyticsInstalled'),
		('IsClustered'),
		('IsFullTextInstalled'),
		('IsHadrEnabled'),
		('IsIntegratedSecurityOnly'),
		('IsLocalDB'),
		('IsPolybaseInstalled'),
		('IsSingleUser'),
		('IsXTPSupported'),
		('LCID'),
		('LicenseType'),
		('MachineName'),
		('NumLicenses'),
		('ProcessID'),
		('ProductBuild'),
		('ProductLevel'),
		('ProductMajorVersion'),
		('ProductMinorVersion'),
		('ProductUpdateLevel'),
		('ProductUpdateReference'),
		('ProductVersion'),
		('ResourceLastUpdateDateTime'),
		('ServerName'),
		('SqlCharSet'),
		('SqlCharSetName'),
		('SqlSortOrder'),
		('SqlSortOrderName'),
		('FilestreamShareName'),
		('FilestreamConfiguredLevel'),
		('FilestreamEffectiveLevel');

	SELECT [i].[instance_guid]
		,[D1].[datetimeoffset]
		,[property]
		,[value]=CAST(SERVERPROPERTY([property]) AS NVARCHAR(128)) 
	FROM @server_properties [p]
		CROSS APPLY [system].[get_instance_guid]() [i]
		CROSS APPLY [system].[get_datetimeoffset](SYSDATETIME()) [D1]
	UNION 
	SELECT [i].[instance_guid]
		,[D1].[datetimeoffset]
		,[property] = 'GlobalTraceFlags'
		,[value]=REPLACE(REPLACE(REPLACE((SELECT [flag] FROM @flags WHERE [enabled]=1 AND [global]=1 FOR XML PATH('')),'</flag><flag>',', '),'<flag>', ''),'</flag>','')
	FROM [system].[get_instance_guid]() [i]
		CROSS APPLY [system].[get_datetimeoffset](SYSDATETIME()) [D1]

	IF (@update_execution_timestamp = 1)
		MERGE INTO [collector].[last_execution] AS [Target]
		USING (SELECT OBJECT_NAME(@@PROCID), GETDATE()) AS [Source]([object_name],[last_execution])
		ON [Target].[object_name] = [Source].[object_name]
		WHEN MATCHED THEN
			UPDATE SET [Target].[last_execution] = [Source].[last_execution]
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT ([object_name],[last_execution]) VALUES ([Source].[object_name],[Source].[last_execution]);
END