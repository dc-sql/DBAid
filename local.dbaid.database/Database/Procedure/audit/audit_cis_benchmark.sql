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
			EXEC xp_loginconfig 'audit level';

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

--new
--get orphaned database users
IF OBJECT_ID('tempdb..#__orphan') IS NOT NULL
	DROP TABLE #__orphan;		
CREATE TABLE #__orphan ([DbName] NVARCHAR(128) NULL, [name] NVARCHAR(128), [UserSID] VARBINARY(85))

EXEC foreachdb N'USE [?]; 
				INSERT INTO #__orphan 
				(name,UserSID)
				EXEC sp_change_users_login @Action=''Report''
				UPDATE #__orphan SET [DbName] = N''?'' WHERE [DbName] IS NULL;';


--get guests with connect permissions
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


DECLARE @results AS TABLE([cis_id] NVARCHAR(4), [policy_name] NVARCHAR(1024), [pass] INT)

--2. Surface Area Reduction 
INSERT INTO @results
SELECT '2.1','Ad Hoc Distributed Queries Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'ad hoc distributed queries'
INSERT INTO @results
SELECT '2.2', 'CLR Enabled Server Configuration Option to 0 (Scored) ' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'CLR enabled'
INSERT INTO @results
SELECT '2.3', 'Set the Cross DB Ownership Chaining Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'Cross db ownership chaining'
INSERT INTO @results
SELECT '2.4', 'Set the Database Mail XPs Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'Database Mail XPs'
INSERT INTO @results
SELECT '2.5', 'Set the Ole Automation Procedures Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'Ole Automation Procedures'
INSERT INTO @results
SELECT '2.6', 'Set the Remote Access Server Configuration Option to 0 (Scored) ' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'Remote access'
INSERT INTO @results
SELECT '2.7', 'Set the Remote Admin Connections Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'Remote admin connections'
INSERT INTO @results
SELECT '2.8', 'Set the Scan For Startup Procs Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'Scan for startup procs'
INSERT INTO @results
SELECT '2.9', 'Set the Trustworthy Database Property to Off (Scored)' AS [Policy Name], CASE WHEN COUNT([database_id]) > 0 THEN 0 ELSE 1 END AS [pass] FROM [master].[sys].[databases] WHERE [is_trustworthy_on] = 1 AND [name] != 'msdb' AND [state] = 0
INSERT INTO @results
SELECT '2.10', 'Disable Unnecessary SQL Server Protocols – ‘Shared Memory and TCP/IP Protocol is enabled’ (Not Scored)' AS [Policy Name] ,CASE WHEN [value] = 'True' THEN 0 ELSE 1 END AS [score] FROM [info].[service] WHERE [property] = 'Shared Memory'
INSERT INTO @results
SELECT '2.11','Configure SQL Server to use non-standard ports (Not Scored)' AS [Policy Name], CASE WHEN [value] = '1433' THEN 0 ELSE 1 END AS [score] FROM [info].[service] WHERE [property] = 'TcpPort'
INSERT INTO @results
SELECT '2.12','Set the Hide Instance option to Yes for Production SQL Server instances (Scored)' AS [Policy Name], CASE WHEN [value] = 'False' THEN 0 ELSE 1 END AS [score] FROM [info].[service] WHERE [property] = 'HideInstance'
INSERT INTO @results
SELECT '2.13','Disable the sa Login Account (Scored)' AS [Policy Name], CASE WHEN [is_disabled] = 0 THEN 0 ELSE 1 END AS [score] FROM [master].[sys].[server_principals] WHERE [sid] = 0x01
INSERT INTO @results
SELECT '2.14','Rename the sa Login Account (Scored)' AS [Policy Name], CASE WHEN [name] = 'sa' THEN 0 ELSE 1 END AS [score] FROM [master].[sys].[server_principals] WHERE [sid] = 0x01
INSERT INTO @results
SELECT '2.15','Set the xp_cmdshell Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass] FROM [info].[instance] WHERE [name] = 'xp_cmdshell'

--3. Authentication and Authorization
INSERT INTO @results
SELECT '3.1','Set The Server Authentication Property To Windows Authentication mode (Scored)' AS [Policy Name], CASE WHEN [value] = 0 THEN 0 ELSE 1 END AS [score] FROM [info].[service] WHERE [property] = 'IsIntegratedSecurityOnly'
INSERT INTO @results
SELECT '3.2','Revoke CONNECT permissions on the guest user within all SQL Server databases excluding the master, msdb and tempdb (Scored)' AS [Policy Name], CASE WHEN COUNT([id]) != 0 THEN 0 ELSE 1 END AS [score] FROM #__guest WHERE [id] NOT IN (DB_ID('master'),DB_ID('msdb'),DB_ID('tempdb')) 
INSERT INTO @results
SELECT '3.3','Drop Orphaned Users From SQL Server Databases (Scored)' AS [Policy Name], CASE WHEN COUNT([DbName]) != 0 THEN 0 ELSE 1 END AS [score] FROM #__orphan 



SELECT * FROM @results
END