﻿/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_instance_service_configurations]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @BackupDirectory NVARCHAR(256)
	DECLARE @DefaultFile NVARCHAR(256)
	DECLARE @DefaultLog NVARCHAR(256)
	DECLARE @flags TABLE([flag] INT, [enabled] BIT, [global] BIT, [session] INT);

	EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @BackupDirectory OUTPUT, N'no_ouput'
	EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', @DefaultFile OUTPUT, N'no_ouput'
	EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog', @DefaultLog OUTPUT, N'no_ouput'
	INSERT INTO @flags EXEC('DBCC TRACESTATUS (-1) WITH NO_INFOMSGS');

	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'BuildClrVersion' AS [property]
		,CAST(SERVERPROPERTY('BuildClrVersion') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'Collation' AS [property]
		,CAST(SERVERPROPERTY('Collation') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'ComputerNamePhysicalNetBIOS' AS [property]
		,CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'Edition' AS [property]
		,CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'InstanceName' AS [property]
		,CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'IsClustered' AS [property]
		,CAST(SERVERPROPERTY('IsClustered') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'IsFullTextInstalled' AS [property]
		,CAST(SERVERPROPERTY('IsFullTextInstalled') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'IsIntegratedSecurityOnly' AS [property]
		,CAST(SERVERPROPERTY('IsIntegratedSecurityOnly') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'IsSingleUser' AS [property]
		,CAST(SERVERPROPERTY('IsSingleUser') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'MachineName' AS [property]
		,CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'ProductVersion' AS [property]
		,CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'ProductLevel' AS [property]
		,CAST(SERVERPROPERTY('ProductLevel') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'ResourceLastUpdateDateTime' AS [property]
		,CAST(SERVERPROPERTY('ResourceLastUpdateDateTime') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'ResourceVersion' AS [property]
		,CAST(SERVERPROPERTY('ResourceVersion') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'ServerName' AS [property]
		,CAST(SERVERPROPERTY('ServerName') AS NVARCHAR(128)) AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'BackupDirectory'
		,@BackupDirectory AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'DefaultData'
		,@DefaultFile AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'DefaultLog'
		,@DefaultLog AS [value]
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [class_object]
		,N'TraceFlags' AS [property]
		,STUFF((SELECT N', ' + CAST([flag] AS NCHAR(4)) AS [text()] FROM @flags WHERE [global] = 1 AND [enabled] = 1 FOR XML PATH('')), 1, 2, '') AS [value]
	UNION ALL 
	SELECT [class], [property], CAST([value] AS NVARCHAR(128)) FROM [configg].[wmi_service_property];
END
