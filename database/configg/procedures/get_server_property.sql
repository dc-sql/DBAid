/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_server_property]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'INSTANCE' AS [heading], 'Server Property' AS [subheading], 'Results are from SERVERPROPERTY() system function.' AS [comment]

	DECLARE @flags TABLE([flag] INT, [enabled] BIT, [global] BIT, [session] INT);
	DECLARE @server_properties TABLE ([property] SYSNAME); 

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

	SELECT [property], CAST(SERVERPROPERTY([property]) AS NVARCHAR(128)) FROM @server_properties;
END
