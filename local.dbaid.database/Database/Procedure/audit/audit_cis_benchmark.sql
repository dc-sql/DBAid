/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [audit].[cis_benchmark]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Version NUMERIC(18,10)
	DECLARE @SQLString NVARCHAR(4000);
	
	IF OBJECT_ID('tempdb..#__clr_assembly') IS NOT NULL
	DROP TABLE #__clr_assembly;
	CREATE TABLE #__clr_assembly ( [clr_desc] NVARCHAR(40), [count] INT);
	 
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))
	IF @Version >= 10
	BEGIN
		SET @SQLString =  N'INSERT INTO #__clr_assembly
							SELECT ''CLR Assemblies not having SAFE_ACCESS'', COUNT([permission_set_desc]) FROM [master].[sys].[assemblies] WHERE [is_user_defined] = 1 AND [permission_set_desc] != ''SAFE_ACCESS'''
		EXECUTE sp_executesql @SQLString
	END
	ELSE
	BEGIN
		SET @SQLString =  N'INSERT INTO #__clr_assembly
							SELECT ''CLR Assemblies not having SAFE_ACCESS'', COUNT([permission_set_desc]) FROM [master].[sys].[assemblies] WHERE [name] NOT LIKE ''Microsoft%'' AND [permission_set_desc] != ''SAFE_ACCESS'''
		EXECUTE sp_executesql @SQLString
	END

	DECLARE @loginfo_cmd_list TABLE([property] NVARCHAR(200), [value] NVARCHAR(200));
	INSERT INTO @loginfo_cmd_list([property], [value])
			EXEC XP_loginconfig 'audit level';

	DECLARE @enumerrorlogs TABLE ([archive] INT, [date] DATETIME, [file_size_byte] BIGINT);
	INSERT INTO @enumerrorlogs EXEC [master].[dbo].[xp_enumerrorlogs];

	IF OBJECT_ID('tempdb..#__guest') IS NOT NULL
		DROP TABLE #__guest;		
	CREATE TABLE #__guest (id INT, [name] NVARCHAR(128), [permission_name] NVARCHAR(128))

	EXEC foreachdb N'USE [?]; 
					INSERT INTO #__guest 
						SELECT 
							DB_ID() AS DBName, 
							[dpr].[name], 
							[dpe].[permission_name] 
						FROM [sys].[database_permissions] [dpe] 
							INNER JOIN [sys].[database_principals] [dpr]
								ON [dpe].[grantee_principal_id] = [dpr].[principal_id]
						WHERE 
							[dpr].[name] = ''guest'' 
							AND [dpe].[permission_name] = ''CONNECT''';

		SELECT
			[property]
			,[value]
		FROM [info].[service]
		WHERE 
		[hierarchy] LIKE '%ServerNetworkProtocol%' OR [hierarchy] LIKE '%ServerSettingsGeneralFlag%'
		OR [property] IN ('VERSION','SPLEVEL','IsClustered','IsIntegratedSecurityOnly')
	UNION
		SELECT  [name]
			,[value_in_use]
		FROM [info].[instance]
		WHERE [name] IN ('ad hoc distributed queries',
						'clr enabled','Cross db ownership chaining',
						'Database Mail XPs',
						'Ole Automation Procedures',
						'Remote access',
						'Remote admin connections',
						'Scan for startup procs',
						'xp_cmdshell',
						'Default trace enabled')
	UNION
		SELECT 'SA account is_disabled', [is_disabled] FROM [master].[sys].[server_principals] WHERE [sid] = 0x01
	UNION
		SELECT 'SA account name', [name] FROM [master].[sys].[server_principals] WHERE [sid] = 0x01
	UNION
		SELECT [property], [value] FROM @loginfo_cmd_list
	UNION
		SELECT 'Maximum number of error log files', COUNT([archive])-1 FROM @enumerrorlogs
	UNION
		SELECT 'CONNECT permissions on the ''guest user''', COUNT([id]) FROM #__guest  WHERE [id] > 4
	UNION 
		SELECT [clr_desc], [count] FROM  #__clr_assembly
	UNION
	SELECT 'Trustworthy Database Property', COUNT([database_id]) FROM [master].[sys].[databases] WHERE [is_trustworthy_on] = 1 AND [name] != 'msdb' AND [state] = 0;
END