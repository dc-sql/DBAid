/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[cis_benchmark]
(
	@policy_filter NVARCHAR(10) = NULL
)

WITH ENCRYPTION
AS

BEGIN

	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @errormessage NVARCHAR(MAX)

	IF LOWER(@policy_filter) NOT IN ('failed','notscored')
	BEGIN
		SET @errormessage = 'The value for the parameter @policy_filter is incorrect only supports filters ''failed'' and ''notscored''' + CHAR(13) + CHAR(10) + ' '
		RAISERROR(@errormessage,16,1) WITH NOWAIT
		RETURN
	END

	--setup version info
	DECLARE @Version NUMERIC(18,10);
	DECLARE @SQLString NVARCHAR(4000);

	IF OBJECT_ID('tempdb..#__clr_assembly') IS NOT NULL
	DROP TABLE #__clr_assembly;
	CREATE TABLE #__clr_assembly ([count] INT);
		 
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))
	IF @Version >= 10
	BEGIN
		SET @SQLString =  N'INSERT INTO #__clr_assembly
							SELECT COUNT([permission_set_desc]) FROM [master].[sys].[assemblies] WHERE [is_user_defined] = 1 AND [permission_set_desc] != ''SAFE_ACCESS'''
		EXECUTE sp_executesql @SQLString
	END
	ELSE
	BEGIN
		SET @SQLString =  N'INSERT INTO #__clr_assembly
							SELECT COUNT([permission_set_desc]) FROM [master].[sys].[assemblies] WHERE [name] NOT LIKE ''Microsoft%'' AND [permission_set_desc] != ''SAFE_ACCESS'''
		EXECUTE sp_executesql @SQLString
	END

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

	--get contained database access
	IF OBJECT_ID('tempdb..#__contained_auth') IS NOT NULL
		DROP TABLE #__contained_auth;		
	CREATE TABLE #__contained_auth ([name] NVARCHAR(128) NULL)

	IF OBJECT_ID('tempdb..#__contained') IS NOT NULL
	DROP TABLE #__contained;		
	CREATE TABLE #__contained ([pass] INT NULL, [value] INT NULL)

	IF @Version >= 11
	BEGIN
		EXEC foreachdb N'USE [?]; 
						INSERT INTO #__contained_auth 
						SELECT 
							[name]
						FROM [sys].[database_principals]
						WHERE 
							[name] NOT IN (''dbo'',''Information_Schema'',''sys'',''guest'')
							AND [type] IN (''U'',''S'',''G'')
							AND [authentication_type] = 2';

		SET @SQLString =  N'INSERT INTO #__contained 
							SELECT
							CASE 
								WHEN EXISTS (SELECT 1 FROM [sys].[databases] WHERE [containment] <> 0 and [is_auto_close_on] = 1) THEN 0 
								ELSE 1 
							END AS [pass], 
							(SELECT COUNT([is_auto_close_on]) FROM [sys].[databases] WHERE [containment] <> 0 and [is_auto_close_on] = 1) AS [value]'

		EXECUTE sp_executesql @SQLString
	END

	--get errorlog count
	DECLARE @NumErrorLogs INT
	    EXEC [master].[dbo].[xp_instance_regread] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', @NumErrorLogs OUTPUT

	--get audit level
	DECLARE @loginfo_cmd_list TABLE([property] NVARCHAR(200), [value] NVARCHAR(200));
	INSERT INTO @loginfo_cmd_list([property], [value])
			EXEC xp_loginconfig 'audit level';

	--get asymmetric keys less than 2048 bits
	IF OBJECT_ID('tempdb..#__asymmetric') IS NOT NULL
		DROP TABLE #__asymmetric;		
	CREATE TABLE #__asymmetric ([db_id] INT, [key_name] NVARCHAR(128))

	EXEC foreachdb N'USE [?]; 
					INSERT INTO #__asymmetric 
						SELECT 
							db_id(), 
							[name] 
						FROM sys.asymmetric_keys
						WHERE key_length < 2048
						AND db_id() > 4;'

	--get symmetric keys using bad AES length
	IF OBJECT_ID('tempdb..#__symmetric') IS NOT NULL
		DROP TABLE #__symmetric;		
	CREATE TABLE #__symmetric ([db_id] INT, [key_name] NVARCHAR(128))

	EXEC foreachdb N'USE [?]; 
					INSERT INTO #__symmetric 
						SELECT 
							db_id(), 
							[name] 
						FROM sys.symmetric_keys
						WHERE algorithm_desc NOT IN (''AES_128'',''AES_192'',''AES_256'')
						AND db_id() > 4;'
	
	--get server login audit
	IF OBJECT_ID('tempdb..#__server_audit') IS NOT NULL
		DROP TABLE #__server_audit;
	CREATE TABLE #__server_audit ([count] INT);
		 
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))
	IF @Version >= 10
	BEGIN
		SET @SQLString =  N'INSERT INTO #__server_audit
							SELECT TOP 1 COUNT(*)
							FROM [sys].[server_audit_specification_details] AS [SAD]
							INNER JOIN [sys].[server_audit_specifications] AS [SA] ON [SAD].[server_specification_id] = [SA].[server_specification_id] 
							INNER JOIN [sys].[server_audits] AS [S] ON [SA].[audit_guid] = [S].[audit_guid] 
							WHERE [SAD].[audit_action_id] IN (''CNAU'', ''LGFL'', ''LGSD'')
							AND [SA].[is_state_enabled] = 1 AND [S].[is_state_enabled] = 1
							GROUP BY [S].[name]'
		EXECUTE sp_executesql @SQLString
	END
	
	--get admin group members
	DECLARE @admin_accounts AS TABLE 
	([hierarchy] NVARCHAR(260),
	[value] NVARCHAR(260) NULL)

	INSERT INTO @admin_accounts 
	SELECT [hierarchy],CAST([value] AS NVARCHAR(260))
	FROM [dbo].[service]
	WHERE 
	 [property] = 'StartName'
		AND [value] IN (
			SELECT SUBSTRING(CAST([value] AS NVARCHAR(4000)),CHARINDEX('"',CAST([value] AS NVARCHAR(4000)))+1, CHARINDEX('"',CAST([value] AS NVARCHAR(4000)),CHARINDEX('"',CAST([value] AS NVARCHAR(4000)))+1) - CHARINDEX('"',CAST([value] AS NVARCHAR(4000)))-1) 
			+'\'+
			SUBSTRING([property],CHARINDEX('"',[property])+1, CHARINDEX('"',[property],CHARINDEX('"',[property])+1) - CHARINDEX('"',[property])-1)
			FROM [dbo].[service]
			WHERE [hierarchy] LIKE '%Win32_GroupUser/Local_Admins%')
				AND ([hierarchy] LIKE '%SQLService/MSSQL$%' 
				OR [hierarchy] LIKE '%SQLService/MSSQLSERVER%' 
				OR [hierarchy] LIKE '%SQLService/SQLAgent%' 
				OR [hierarchy] LIKE '%SQLService/SQLSERVERAGENT%'
				OR [hierarchy] LIKE '%SQLService/MSSQLFDLauncher%')

	--setup result table
	DECLARE @results AS TABLE([cis_id] NVARCHAR(4), [policy_name] NVARCHAR(1024), [pass] INT, [value] NVARCHAR(128))

	--2. Surface Area Reduction 
	INSERT INTO @results
	SELECT '2.1','2.1 Ad Hoc Distributed Queries Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'ad hoc distributed queries'
	INSERT INTO @results
	SELECT '2.2','2.2 CLR Enabled Server Configuration Option to 0 (Scored) ' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'CLR enabled'
	INSERT INTO @results
	SELECT '2.3','2.3 Set the Cross DB Ownership Chaining Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'Cross db ownership chaining'
	INSERT INTO @results
	SELECT '2.4','2.4 Set the Database Mail XPs Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'Database Mail XPs'
	INSERT INTO @results
	SELECT '2.5','2.5 Set the Ole Automation Procedures Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'Ole Automation Procedures'
	INSERT INTO @results
	SELECT '2.6','2.6 Set the Remote Access Server Configuration Option to 0 (Scored) ' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'Remote access'
	INSERT INTO @results
	SELECT '2.7','2.7 Set the Remote Admin Connections Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'Remote admin connections'
	INSERT INTO @results
	SELECT '2.8','2.8 Set the Scan For Startup Procs Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'Scan for startup procs'
	INSERT INTO @results
	SELECT '2.9','2.9 Set the Trustworthy Database Property to Off (Scored)' AS [Policy Name], CASE WHEN COUNT([database_id]) > 0 THEN 0 ELSE 1 END AS [pass], CAST(COUNT([database_id]) AS NVARCHAR(10)) AS [value]  FROM [master].[sys].[databases] WHERE [is_trustworthy_on] = 1 AND [name] != 'msdb' AND [state] = 0
	INSERT INTO @results
	SELECT '2.10','2.10 Disable Unnecessary SQL Server Protocols – ‘Shared Memory and TCP/IP Protocol is enabled’ (Not Scored)' AS [Policy Name] ,CASE WHEN [value] = 'True' THEN 0 ELSE 1 END AS [score], CAST([value] AS NVARCHAR(10)) FROM [info].[service] WHERE [property] = 'Shared Memory'
	INSERT INTO @results
	SELECT '2.11','2.11 Configure SQL Server to use non-standard ports (Not Scored)' AS [Policy Name], CASE WHEN [value] = '1433' THEN 0 ELSE 1 END AS [score], CAST([value] AS NVARCHAR(10))FROM [info].[service] WHERE [property] = 'TcpPort'
	INSERT INTO @results
	SELECT '2.12','2.12 Set the Hide Instance option to Yes for Production SQL Server instances (Scored)' AS [Policy Name], CASE WHEN [value] = 'False' THEN 0 ELSE 1 END AS [score], CAST([value] AS NVARCHAR(10)) FROM [info].[service] WHERE [property] = 'HideInstance'
	INSERT INTO @results
	SELECT '2.13','2.13 Disable the sa Login Account (Scored)' AS [Policy Name], CASE WHEN [is_disabled] = 0 THEN 0 ELSE 1 END AS [score], CAST([is_disabled] AS NVARCHAR(10)) AS [value] FROM [master].[sys].[server_principals] WHERE [sid] = 0x01
	INSERT INTO @results
	SELECT '2.14','2.14 Rename the sa Login Account (Scored)' AS [Policy Name], CASE WHEN [name] = 'sa' THEN 0 ELSE 1 END AS [score], [name] AS [value] FROM [master].[sys].[server_principals] WHERE [sid] = 0x01
	INSERT INTO @results
	SELECT '2.15','2.15 Set the xp_cmdshell Server Configuration Option to 0 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 0 ELSE 1 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'xp_cmdshell'
	INSERT INTO @results
	SELECT '2.16','2.16 Ensure ''AUTO_CLOSE OFF'' is set on contained databases (Scored)' AS [Policy Name], [pass], [value] FROM #__contained;
	INSERT INTO @results
	SELECT '2.17','2.17 Ensure no login exists with the name ''sa'' (Scored)' AS [Policy Name], CASE WHEN EXISTS(SELECT [name] FROM [master].[sys].[server_principals] WHERE [name] = 'sa') THEN 0 ELSE 1 END AS [score], CASE WHEN EXISTS(SELECT [name] FROM [master].[sys].[server_principals] WHERE [name] = 'sa') THEN CAST('sa' AS NVARCHAR(128)) ELSE '0' END AS [value]

	--3. Authentication and Authorization
	INSERT INTO @results
	SELECT '3.1','3.1 Set The Server Authentication Property To Windows Authentication mode (Scored)' AS [Policy Name], CASE WHEN [value] = 0 THEN 0 ELSE 1 END AS [score], CAST([value] AS NVARCHAR(10)) AS [value] FROM [info].[service] WHERE [property] = 'IsIntegratedSecurityOnly'
	INSERT INTO @results
	SELECT '3.2','3.2 Revoke CONNECT permissions on the guest user within all SQL Server databases excluding the master, msdb and tempdb (Scored)' AS [Policy Name], CASE WHEN COUNT([id]) != 0 THEN 0 ELSE 1 END AS [score], CAST(COUNT([id]) AS NVARCHAR(10)) AS [value] FROM #__guest WHERE [id] NOT IN (DB_ID('master'),DB_ID('msdb'),DB_ID('tempdb')) 
	INSERT INTO @results
	SELECT '3.3','3.3 Drop Orphaned Users From SQL Server Databases (Scored)' AS [Policy Name], CASE WHEN COUNT([DbName]) != 0 THEN 0 ELSE 1 END AS [score], CAST(COUNT([DbName]) AS NVARCHAR(10)) AS [value] FROM #__orphan 
	INSERT INTO @results
	SELECT '3.4','3.4 Do not use SQL Authentication in contained databases (Scored)' AS [Policy Name], CASE WHEN COUNT([name]) != 0 THEN 0 ELSE 1 END AS [score], CAST(COUNT([name]) AS NVARCHAR(10)) AS [value] FROM #__contained_auth

	IF EXISTS (SELECT [value] FROM @admin_accounts WHERE [hierarchy] LIKE '%SQLService/MSSQL$%' OR [hierarchy] LIKE '%SQLService/MSSQLSERVER%')
	BEGIN
		INSERT INTO @results
	    SELECT '3.5','3.5 Ensure the SQL Server''s MSSQL Service Account is Not an Administrator (Scored)' AS [Policy Name],
			0 AS [score],
			[value]
		FROM @admin_accounts
		WHERE 
		  [hierarchy] LIKE '%SQLService/MSSQL$%' OR [hierarchy] LIKE '%SQLService/MSSQLSERVER%'
	END
	ELSE
	BEGIN
		INSERT INTO @results
		SELECT '3.5','3.5 Ensure the SQL Server''s MSSQL Service Account is Not an Administrator (Scored)' AS [Policy Name],
			1 AS [score],
			'0'
	END 

	IF EXISTS (SELECT [value] FROM @admin_accounts WHERE [hierarchy] LIKE '%SQLService/SQLAgent%' OR [hierarchy] LIKE '%SQLService/SQLSERVERAGENT%')
	BEGIN
		INSERT INTO @results
	    SELECT '3.6','3.6 Ensure the SQL Server''s SQLAgent Service Account is Not an Administrator (Scored)' AS [Policy Name],
			0 AS [score],
			[value]
		FROM @admin_accounts
		WHERE 
		  [hierarchy] LIKE '%SQLService/SQLAgent%' OR [hierarchy] LIKE '%SQLService/SQLSERVERAGENT%'
	END
	ELSE
	BEGIN
		INSERT INTO @results
		SELECT '3.6','3.6 Ensure the SQL Server''s SQLAgent Service Account is Not an Administrator (Scored)' AS [Policy Name],
			1 AS [score],
			'0'
	END 

	IF EXISTS (SELECT [value] FROM @admin_accounts WHERE [hierarchy] LIKE '%SQLService/MSSQLFDLauncher%')
	BEGIN
		INSERT INTO @results
	    SELECT '3.7','3.7 Ensure the SQL Server''s Full-Text Service Account is Not an Administrator (Scored)' AS [Policy Name],
			0 AS [score],
			[value]
		FROM @admin_accounts
		WHERE 
		  [hierarchy] LIKE '%SQLService/MSSQLFDLauncher%'
	END
	ELSE
	BEGIN
		INSERT INTO @results
		SELECT '3.7','3.7 Ensure the SQL Server''s Full-Text Service Account is Not an Administrator (Scored)' AS [Policy Name],
			1 AS [score],
			'0'
	END


	INSERT INTO @results
	SELECT '3.8','3.8 Ensure only the default permissions specified by Microsoft are granted to the public server role (Scored)' AS [Policy Name], 
		CASE WHEN COUNT(*) != 0 THEN 0 ELSE 1 END AS [score], CAST(COUNT(*) AS NVARCHAR(10)) AS [value] 
	FROM [master].[sys].[server_permissions]
		WHERE (grantee_principal_id = SUSER_SID(N'public') and state_desc LIKE
		'GRANT%')
		AND NOT (state_desc = 'GRANT' and [permission_name] = 'VIEW ANY DATABASE'
		and class_desc = 'SERVER')
		AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and
		class_desc = 'ENDPOINT' and major_id = 2)
		AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and
		class_desc = 'ENDPOINT' and major_id = 3)
		AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and
		class_desc = 'ENDPOINT' and major_id = 4)
		AND NOT (state_desc = 'GRANT' and [permission_name] = 'CONNECT' and
	class_desc = 'ENDPOINT' and major_id = 5);

	INSERT INTO @results
	SELECT '3.9','3.9 Ensure Windows BUILTIN groups are not SQL Logins (Scored)' AS [Policy Name], 
	CASE WHEN EXISTS(SELECT pr.[name], pe.[permission_name], pe.[state_desc]
				FROM sys.server_principals pr
				JOIN sys.server_permissions pe
				ON pr.principal_id = pe.grantee_principal_id
				WHERE pr.name like 'BUILTIN%')
	THEN 0 ELSE 1 END AS [score],
	(SELECT CAST(COUNT(*) AS NVARCHAR(10))
	FROM sys.server_principals pr
	JOIN sys.server_permissions pe
	ON pr.principal_id = pe.grantee_principal_id
	WHERE pr.name like 'BUILTIN%') AS [value]

	INSERT INTO @results
	SELECT '3.10','3.10 Ensure Windows local groups are not SQL Logins (Scored)' AS [Policy Name], 
	CASE WHEN EXISTS(SELECT pr.[name] AS LocalGroupName, pe.[permission_name], pe.[state_desc]
				FROM sys.server_principals pr
				JOIN sys.server_permissions pe
				ON pr.[principal_id] = pe.[grantee_principal_id]
				WHERE pr.[type_desc] = 'WINDOWS_GROUP'
				AND pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%')
	THEN 0 ELSE 1 END AS [score],
	(SELECT CAST(COUNT(*) AS NVARCHAR(10))
				FROM sys.server_principals pr
				JOIN sys.server_permissions pe
				ON pr.[principal_id] = pe.[grantee_principal_id]
				WHERE pr.[type_desc] = 'WINDOWS_GROUP'
			AND pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%') AS [value]

	INSERT INTO @results
	SELECT '3.11','3.11 Ensure the public role in the msdb database is not granted access to SQL Agent proxies (Scored)' AS [Policy Name],
	CASE WHEN EXISTS(SELECT [sp].[name] AS proxyname
				FROM [msdb].[dbo].[sysproxylogin] [spl]
				INNER JOIN [msdb].[sys].[database_principals] [dp]
				ON [dp].[sid] = [spl].[sid]
				INNER JOIN [msdb].[dbo].[sysproxies] sp
				ON [sp].[proxy_id] = [spl].[proxy_id]
				WHERE [principal_id] = USER_ID('public'))
	THEN 0 ELSE 1 END AS [score],
	(SELECT CAST(COUNT(*) AS NVARCHAR(10))
				FROM [msdb].[dbo].[sysproxylogin] [spl]
				INNER JOIN [msdb].[sys].[database_principals] [dp]
				ON [dp].[sid] = [spl].[sid]
				INNER JOIN [msdb].[dbo].[sysproxies] sp
				ON [sp].[proxy_id] = [spl].[proxy_id]
				WHERE [principal_id] = USER_ID('public')) AS [value]

	--4. Password Policies
	INSERT INTO @results
	SELECT '4.1','4.1 Set the MUST_CHANGE Option to ON for All SQL Authenticated Logins (Not Scored)' AS [Policy Name], CASE WHEN EXISTS (SELECT 1 FROM [master].[sys].[sql_logins] WHERE ([is_policy_checked] != 1 OR [is_expiration_checked] != 1) AND [name] NOT IN ('##MS_PolicyTsqlExecutionLogin##','##MS_PolicyEventProcessingLogin##')) 
	THEN 0 ELSE 1 END AS [score], 
	(SELECT CAST(COUNT([sid]) AS NVARCHAR(10)) FROM [master].[sys].[sql_logins] WHERE ([is_policy_checked] != 1 OR [is_expiration_checked] != 1) AND [name] NOT IN ('##MS_PolicyTsqlExecutionLogin##','##MS_PolicyEventProcessingLogin##')) AS [value]

	INSERT INTO @results
	SELECT '4.2','4.2 Set the CHECK_EXPIRATION Option to ON for All SQL Authenticated Logins Within the Sysadmin Role (Scored)' AS [Policy Name], 
	CASE WHEN EXISTS (
		SELECT 1
		FROM [sys].[sql_logins] AS l
		WHERE IS_SRVROLEMEMBER('sysadmin',[name]) = 1
		AND [l].[is_expiration_checked] <> 1
		UNION ALL
		SELECT 1
		FROM [sys].[sql_logins] AS l
		INNER JOIN [sys].[server_permissions] AS p
		ON [l].[principal_id] = [p].[grantee_principal_id]
		WHERE [p].[type] = 'CL' AND [p].[state] IN ('G', 'W')
		AND [l].[is_expiration_checked] <> 1
	) THEN 0 ELSE 1 END AS [score],
	(SELECT
	CAST((SELECT COUNT([name])
			FROM [sys].[sql_logins] AS l
			WHERE IS_SRVROLEMEMBER('sysadmin',[name]) = 1
			AND [l].[is_expiration_checked] <> 1)
		+
		(SELECT COUNT([name])
			FROM [sys].[sql_logins] AS l
			INNER JOIN [sys].[server_permissions] AS p
			ON [l].[principal_id] = [p].[grantee_principal_id]
			WHERE [p].[type] = 'CL' AND [p].[state] IN ('G', 'W')
			AND [l].[is_expiration_checked] <> 1) 
		AS NVARCHAR(10))
	AS [value])

	INSERT INTO @results
	SELECT '4.3','4.3 Set the CHECK_POLICY Option to ON for All SQL Authenticated Logins (Scored)' AS [Policy Name], CASE WHEN EXISTS (SELECT 1 FROM [master].[sys].[sql_logins] WHERE [is_policy_checked] != 1) THEN 0 ELSE 1 END AS [score], (SELECT CAST(COUNT([name]) AS NVARCHAR(10)) AS [value] FROM [master].[sys].[sql_logins] WHERE [is_policy_checked] != 1)

	--5. Auditing and Logging
	INSERT INTO @results
	SELECT '5.1', '5.1 Set the Maximum number of error log files setting to greater than or equal to 12 (Not Scored)' AS [Policy Name], CASE WHEN ISNULL(@NumErrorLogs,6) >= 12 THEN 1 ELSE 0 END AS [score], ISNULL(@NumErrorLogs,6) AS [value]
	INSERT INTO @results
	SELECT '5.2', '5.2 Set the Default Trace Enabled Server Configuration Option to 1 (Scored)' AS [Policy Name], CASE [value_in_use] WHEN 1 THEN 1 ELSE 0 END AS [pass], CAST([value_in_use] AS NVARCHAR(10)) AS [value] FROM [info].[instance] WHERE [name] = 'default trace enabled'
	INSERT INTO @results
	SELECT '5.3', '5.3 Set Login Auditing to failed logins (Not Scored)' AS [Policy Name], CASE [value] WHEN 'failure' THEN 1 ELSE 0 END AS [pass], [value] FROM @loginfo_cmd_list
	INSERT INTO @results
	SELECT '5.4', '5.4 Use SQL Server Audit to capture both failed and successful logins (Scored)' AS [Policy Name], CASE WHEN (SELECT COUNT(*) FROM #__server_audit) > 0 THEN 1 ELSE 0 END AS [score], ISNULL((SELECT CAST([count] AS NVARCHAR(1)) FROM #__server_audit),'0') AS [value]
	--6. Application Development
	INSERT INTO @results
	SELECT '6.2', '6.2 Set the CLR Assembly Permission Set to SAFE_ACCESS for All CLR Assemblies (Scored)' AS [Policy Name], CASE [count] WHEN 0 THEN 1 ELSE 0 END AS [pass], CAST([count] AS NVARCHAR(10)) AS [value] FROM #__clr_assembly

	--7. Encryption
	INSERT INTO @results
	SELECT '7.1', '7.1 Ensure Symmetric Key encryption algorithm is AES_128 or higher in non-system databases (Scored)' AS [Policy Name], CASE WHEN EXISTS (SELECT 1 FROM #__symmetric) THEN 0 ELSE 1 END AS [score], (SELECT CAST(COUNT([db_id]) AS NVARCHAR(10)) FROM #__symmetric) AS [value]
	INSERT INTO @results
	SELECT '7.2', '7.2 Ensure asymmetric key size is greater than or equal to 2048 in nonsystem databases (Scored)' AS [Policy Name], CASE WHEN EXISTS (SELECT 1 FROM #__asymmetric) THEN 0 ELSE 1 END AS [score], (SELECT CAST(COUNT([db_id]) AS NVARCHAR(10)) FROM #__asymmetric) AS [value]

	--8. Appendix: Additional Considerations
    INSERT INTO @results
	SELECT '8.1', '8.1 SQL Server Browser Service Disabled (Not Scored)' AS [Policy Name], CASE [value] WHEN '4' THEN 1 ELSE 0 END AS [score], CAST([value] AS NVARCHAR(1)) AS [value] FROM [dbo].[service] WHERE [hierarchy] LIKE '%SQLBrowser' AND [property] = 'StartMode'
	
	--results
	DECLARE @audit_total INT
	DECLARE @audit_result INT
	DECLARE @audit_notscored INT
	
	SELECT @audit_result = COUNT([pass]) FROM @results WHERE [policy_name] NOT LIKE '%(Not Scored)%' AND [pass] = 1
	SELECT @audit_total = COUNT([pass]) FROM @results WHERE [policy_name] NOT LIKE '%(Not Scored)%'
	SELECT @audit_notscored = COUNT([pass]) FROM @results WHERE [policy_name] LIKE '%(Not Scored)%'

	INSERT INTO @results
	SELECT '', 'Total Score = '+CAST(@audit_result AS NVARCHAR(2)) +'/'+CAST(@audit_total AS NVARCHAR(2)) + '  Failed = '+(CAST(@audit_total - @audit_result AS NVARCHAR(2)))+ '  Not Scored = '+CAST(@audit_notscored AS NVARCHAR(2)), @audit_result, ''

	IF (LOWER(@policy_filter) = 'failed')
	BEGIN
		SELECT [policy_name], [pass], [value] from @results WHERE [policy_name] NOT LIKE '%Not Scored%' AND [pass] = 0 OR [policy_name] LIKE 'Total Score%'
	END
	ELSE IF (LOWER(@policy_filter) = 'notscored')
	BEGIN
		SELECT [policy_name], [pass], [value] FROM @results WHERE [policy_name] LIKE '%Not Scored%'
	END
	ELSE
	BEGIN
		SELECT [policy_name], [pass], [value] FROM @results
	END

	REVERT;
END