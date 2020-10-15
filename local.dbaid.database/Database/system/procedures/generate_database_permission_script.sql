/*
This is useful for scripting permissions in a development environment before refreshing development with a copy of production.  
This will allow us to easily ensure development permissions are not lost during a prod to dev restoration. 

Thanks to original Author: S. Kusen
Source: https://www.sqlservercentral.com/scripts/script-db-level-permissions-v4-3

PARAMETERS
	INPUT
		@database_name SYSNAME = NULL
		Filter by database name. NULL returns all.

		@principal_name SYSNAME = NULL
		Filter by pricipal name. NULL returns all.
		
		@principal_type BIT = NULL
		Filter by pricipal type. NULL returns all.

		@script_type BIT = NULL
		Filter by script type. NULL returns all.
*/

CREATE PROCEDURE [system].[generate_database_permission_script] 
(
	@database_name sysname = NULL
	,@principal_name sysname = NULL
	,@principal_type NVARCHAR(60) = NULL
	,@script_type VARCHAR(20) = NULL
) 
WITH ENCRYPTION
AS
BEGIN
/*
This is useful for scripting permissions in a development environment before refreshing
   development with a copy of production.  This will allow us to easily ensure
   development permissions are not lost during a prod to dev restoration. 


*/

	SET NOCOUNT ON

	DECLARE @tbl_db_principals_statements TABLE (
		[id] INT IDENTITY(1,1) PRIMARY KEY,
		[database_name] sysname NOT NULL,
		[principal_name] sysname NOT NULL,
		[principal_type] NVARCHAR(60) NOT NULL,
		[script_type] VARCHAR(20) NOT NULL,
		[script] VARCHAR(MAX) NULL
	);

	/*********************************************/
	/*********     DB USER CREATION      *********/
	/*********************************************/
	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [rm].[name]
			,[principal_type] = [rm].[type_desc]
			,[script_type] = ''create_user''
			,[script] = CASE WHEN [rm].[authentication_type] IN (2, 0) /* 2=contained database user with password, 0 =user without login; create users without logins*/ 
				THEN ''IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = N'''''' 
					+ [name] 
					+ '''''') CREATE USER '' 
					+ QUOTENAME([name]) 
					+ '' WITHOUT LOGIN WITH DEFAULT_SCHEMA = '' 
					+ QUOTENAME([default_schema_name]) 
					+ '', SID = '' 
					+ CONVERT(VARCHAR(128), [sid], 1)
					+ '';''
				ELSE ''IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = N'''''' 
					+ [name] 
					+ '''''') CREATE USER '' 
					+ QUOTENAME([name]) 
					+ '' FOR LOGIN '' 
					+ QUOTENAME(SUSER_SNAME([sid])) 
					+ CASE WHEN [type] <> ''G'' THEN '' WITH DEFAULT_SCHEMA = '' + QUOTENAME(ISNULL([default_schema_name], ''dbo'')) ELSE '''' END 
					+ '';''
				END
		FROM sys.database_principals AS rm
		WHERE [type] IN (''U'', ''S'', ''G'') /* windows users, sql users, windows groups */
			AND [rm].[name] NOT IN (N''dbo'',N''guest'',N''INFORMATION_SCHEMA'',N''sys'',N''MS_DataCollectorInternalUser'')
			AND (([rm].[authentication_type] IN (1, 3) AND SUSER_SNAME([sid]) IS NOT NULL) OR ([rm].[authentication_type] IN (0, 2)))';

	/*********************************************/
	/*********    MAP ORPHANED USERS     *********/
	/*********************************************/
	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [dp].[name]
			,[principal_type] = [dp].[type_desc]
			,[script_type] = ''map_orphaned_user''
			,[script] = ''ALTER USER '' 
			+ QUOTENAME([dp].[name]) 
			+ '' WITH LOGIN = '' 
			+ QUOTENAME([dp].[name])
		FROM sys.database_principals [dp]
			INNER JOIN sys.server_principals [sp]
				ON [dp].[name] = [sp].[name] COLLATE DATABASE_DEFAULT 
					AND [dp].[sid] <> [sp].[sid]
		WHERE [dp].[type] IN (''U'', ''S'', ''G'') -- windows users, sql users, windows groups
			AND [dp].[name] NOT IN (N''dbo'',N''guest'',N''INFORMATION_SCHEMA'',N''sys'',N''MS_DataCollectorInternalUser'')';

	/*********************************************/
	/*********    DB ROLE PERMISSIONS    *********/
	/*********************************************/
	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [name]
			,[principal_type] = [type_desc]
			,[script_type] = ''role_permission''
			,[script] = ''IF DATABASE_PRINCIPAL_ID('' 
			+ QUOTENAME([name],'''''''') COLLATE DATABASE_DEFAULT 
			+ '') IS NULL CREATE ROLE ''
			+ QUOTENAME([name])
			+ '';''
		FROM sys.database_principals
		WHERE [type] =''R'' -- R = Role
		AND [is_fixed_role] = 0';

	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [dp].[name]
			,[principal_type] = [dp].[type_desc]
			,[script_type] = ''role_permission''
			,[script] = ''IF DATABASE_PRINCIPAL_ID('' 
			+ QUOTENAME(USER_NAME([rm].[member_principal_id]),'''''''') COLLATE DATABASE_DEFAULT 
			+ '') IS NOT NULL EXEC sp_addrolemember @rolename = ''
			+ QUOTENAME(USER_NAME([rm].[role_principal_id]), '''''''') COLLATE DATABASE_DEFAULT 
			+ '', @membername = '' 
			+ QUOTENAME(USER_NAME([rm].[member_principal_id]), '''''''') COLLATE DATABASE_DEFAULT
			+ '';''
		FROM sys.database_role_members [rm]
			INNER JOIN sys.database_principals [dp]
				ON rm.member_principal_id = [dp].[principal_id]
		WHERE [dp].[principal_id] > 4 -- 0 to 4 are system users/schemas
			AND [dp].[type] IN (''G'',''S'',''U'') -- S = SQL user, U = Windows user, G = Windows group';

	/*********************************************/
	/*********  OBJECT LEVEL PERMISSIONS *********/
	/*********************************************/
	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [dp].[name]
			,[principal_type] = [dp].[type_desc]
			,[script_type] = ''object_permission''
			,[script] = ''IF DATABASE_PRINCIPAL_ID('' 
			+ QUOTENAME(USER_NAME([dp].[principal_id]),'''''''') COLLATE DATABASE_DEFAULT 
			+ '') IS NOT NULL ''
			+ CASE WHEN [perm].[state] <> ''W'' THEN [perm].[state_desc] ELSE ''GRANT '' END
			+ [perm].[permission_name] 
			+ '' ON '' 
			+ QUOTENAME(OBJECT_SCHEMA_NAME([perm].[major_id])) 
			+ ''.'' 
			+ QUOTENAME(OBJECT_NAME([perm].[major_id])) --select, execute, etc on specific objects
			+ CASE WHEN [c].[column_id] IS NULL THEN '''' ELSE ''('' + QUOTENAME([c].[name]) + '')'' END
			+ '' TO '' 
			+ QUOTENAME(USER_NAME([dp].[principal_id])) COLLATE DATABASE_DEFAULT
			+ CASE WHEN [perm].[state] <> ''W'' THEN '';'' ELSE '' WITH GRANT OPTION;'' END
		FROM sys.database_permissions [perm] /* No join to sys.objects as it excludes system objects such as extended stored procedures */
			INNER JOIN sys.database_principals [dp]
				ON [perm].[grantee_principal_id] = [dp].[principal_id]
			LEFT JOIN sys.columns [c] 
				ON [c].[column_id] = [perm].[minor_id] 
					AND [c].[object_id] = [perm].[major_id]
		WHERE DB_NAME() IN (N''master'') /* Include System objects when scripting permissions for master, exclude elsewhere */
			OR (DB_NAME() NOT IN (N''master'') AND [perm].[major_id] IN (SELECT [object_id] FROM sys.objects WHERE [type] NOT IN (''S'')))';

	/*********************************************/
	/*********  TYPE LEVEL PERMISSIONS ***********/
	/*********************************************/
	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [dp].[name]
			,[principal_type] = [dp].[type_desc]
			,[script_type] = ''type_permission''
			,[script] = ''IF DATABASE_PRINCIPAL_ID('' 
			+ QUOTENAME(USER_NAME([dp].[principal_id]),'''''''') COLLATE DATABASE_DEFAULT 
			+ '') IS NOT NULL '' 
			+ CASE WHEN [perm].[state] <> ''W'' THEN [perm].[state_desc] ELSE ''GRANT '' END
			+ [perm].[permission_name] + '' ON '' 
			+ QUOTENAME(SCHEMA_NAME([t].[schema_id])) 
			+ ''.'' 
			+ QUOTENAME([t].[name]) --select, execute, etc on specific objects
			+ '' TO ''
			+ QUOTENAME(USER_NAME([dp].[principal_id])) COLLATE DATABASE_DEFAULT
			+ CASE WHEN [perm].[state] <> ''W'' THEN '';'' ELSE '' WITH GRANT OPTION;'' END
		FROM sys.database_permissions [perm]
			INNER JOIN sys.types [t]
				ON [perm].[major_id] = [t].[user_type_id]
			INNER JOIN sys.database_principals [dp]
				ON [perm].[grantee_principal_id] = [dp].[principal_id]';

	/*********************************************/
	/*********    DB LEVEL PERMISSIONS   *********/
	/*********************************************/
	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [dp].[name]
			,[principal_type] = [dp].[type_desc]
			,[script_type] = ''database_permission''
			,[script] = ''IF DATABASE_PRINCIPAL_ID('' 
			+ QUOTENAME(USER_NAME([dp].[principal_id]),'''''''') COLLATE DATABASE_DEFAULT 
			+ '') IS NOT NULL ''
			+ CASE WHEN [perm].[state] <> ''W'' THEN [perm].[state_desc] ELSE ''GRANT'' END
			+ SPACE(1) + [perm].[permission_name]
			+ '' TO '' 
			+ QUOTENAME(USER_NAME([dp].[principal_id])) COLLATE DATABASE_DEFAULT
			+ CASE WHEN [perm].[state] <> ''W'' THEN '';'' ELSE '' WITH GRANT OPTION;'' END
		FROM sys.database_permissions [perm]
			INNER JOIN sys.database_principals [dp]
				ON [perm].[grantee_principal_id] = [dp].[principal_id]
		WHERE [perm].[major_id] = 0
			AND [dp].[principal_id] > 4 -- 0 to 4 are system users/schemas
			AND [dp].[type] IN (''G'',''S'',''U'') -- S = SQL user, U = Windows user, G = Windows group';

	INSERT INTO @tbl_db_principals_statements ([database_name], [principal_name], [principal_type], [script_type], [script])
		EXEC [system].[execute_foreach_db] N'USE [?]; SELECT [database_name] = DB_NAME()
			,[principal_name] = [dp].[name]
			,[principal_type] = [dp].[type_desc]
			,[script_type] = ''database_permission''
			,[script] =''IF DATABASE_PRINCIPAL_ID('' 
			+ QUOTENAME(USER_NAME([perm].[grantee_principal_id]),'''''''') COLLATE DATABASE_DEFAULT 
			+ '') IS NOT NULL ''
			+ CASE WHEN [perm].[state] <> ''W'' THEN [perm].[state_desc] ELSE ''GRANT''	END
			+ SPACE(1) + [perm].[permission_name] --CONNECT, etc
			+ '' ON '' + [perm].[class_desc] + ''::'' COLLATE DATABASE_DEFAULT --TO <user name>
			+ QUOTENAME(SCHEMA_NAME([perm].[major_id]))
			+ '' TO '' + QUOTENAME(USER_NAME([perm].[grantee_principal_id])) COLLATE DATABASE_DEFAULT
			+ CASE WHEN [perm].[state] <> ''W'' THEN '';'' ELSE '' WITH GRANT OPTION;'' END
		FROM sys.database_permissions [perm]
			INNER JOIN sys.schemas [s]
				ON [perm].[major_id] = [s].[schema_id]
			INNER JOIN sys.database_principals [dp]
				ON [perm].[grantee_principal_id] = [dp].[principal_id]
		WHERE [perm].[class] = 3 --class 3 = schema';

	SELECT [database_name]
		,[principal_name]
		,[principal_type]
		,[script_type]
		,[script]
	FROM @tbl_db_principals_statements
	WHERE ([database_name] = @database_name OR ISNULL(@database_name,'')='')
		AND ([principal_name] = @principal_name OR ISNULL(@principal_name,'')='')
		AND ([principal_type] = @principal_type OR ISNULL(@principal_type,'')='')
		AND ([script_type] = @script_type OR ISNULL(@script_type,'')='')
	ORDER BY [database_name]
		,[id];
END