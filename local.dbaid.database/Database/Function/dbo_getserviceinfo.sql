/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[getserviceinfo]()
RETURNS 
@ServiceConfig TABLE
(
	[hierarchy] NVARCHAR(260)
	,[property] NVARCHAR(128)
	,[value] SQL_VARIANT
)
WITH ENCRYPTION
AS
BEGIN
	DECLARE @BackupDirectory SQL_VARIANT
	DECLARE @DefaultFile SQL_VARIANT
	DECLARE @DefaultLog SQL_VARIANT

	EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupDirectory OUTPUT, N'no_ouput'
	EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DefaultFile OUTPUT, N'no_ouput'
	EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @DefaultLog OUTPUT, N'no_ouput'
	
	INSERT INTO @ServiceConfig
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'BuildClrVersion' AS [property]
			,CAST(SERVERPROPERTY('BuildClrVersion') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'Collation' AS [property]
			,CAST(SERVERPROPERTY('Collation') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ComputerNamePhysicalNetBIOS' AS [property]
			,CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'Edition' AS [property]
			,CAST(SERVERPROPERTY('Edition') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'InstanceName' AS [property]
			,CAST(SERVERPROPERTY('InstanceName') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'IsClustered' AS [property]
			,CAST(SERVERPROPERTY('IsClustered') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'IsFullTextInstalled' AS [property]
			,CAST(SERVERPROPERTY('IsFullTextInstalled') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'IsIntegratedSecurityOnly' AS [property]
			,CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'IsSingleUser' AS [property]
			,CAST(SERVERPROPERTY('IsSingleUser') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'LicenseType' AS [property]
			,CAST(SERVERPROPERTY('LicenseType') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'MachineName' AS [property]
			,CAST(SERVERPROPERTY('MachineName') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'NumLicenses' AS [property]
			,CAST(SERVERPROPERTY('NumLicenses') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ProcessID' AS [property]
			,CAST(SERVERPROPERTY('ProcessID') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ProductVersion' AS [property]
			,CAST(SERVERPROPERTY('ProductVersion') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ProductLevel' AS [property]
			,CAST(SERVERPROPERTY('ProductLevel') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ResourceLastUpdateDateTime' AS [property]
			,CAST(SERVERPROPERTY('ResourceLastUpdateDateTime') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ResourceVersion' AS [property]
			,CAST(SERVERPROPERTY('ResourceVersion') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'ServerName' AS [property]
			,CAST(SERVERPROPERTY('ServerName') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'SqlCharSetName' AS [property]
			,CAST(SERVERPROPERTY('SqlCharSetName') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'SqlSortOrderName' AS [property]
			,CAST(SERVERPROPERTY('SqlSortOrderName') AS SQL_VARIANT) AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'BackupDirectory'
			,@BackupDirectory AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'DefaultData'
			,@DefaultFile AS [value]
		UNION ALL
		SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
			,N'DefaultLog'
			,@DefaultLog AS [value]
		UNION ALL 
		SELECT [hierarchy], [property], [value] FROM [dbo].[service]
	
	RETURN 
END
GO