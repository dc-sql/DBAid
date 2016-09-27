/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

/*
Author: Wayne Teutenberg
Date: 04/03/2013
Desc: Returns login information, SQL, Windows, and Group logins. Login details with server and database role mappings, and simple bad password checking capability. 
*/

CREATE PROCEDURE [configg].[security]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @loginfo_sid VARBINARY(85);
	DECLARE @loginfo_cmd VARCHAR(200);
	DECLARE @loginfo_cmd_list TABLE([group_sid] VARBINARY(85), [logininfo_cmd] VARCHAR(200));
	DECLARE loginfo_cmd_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT [group_sid], [logininfo_cmd] FROM @loginfo_cmd_list;
	DECLARE @login_info TABLE([group_sid] VARBINARY(85), [account_name] NVARCHAR(128), [type] CHAR(8), [privilege] CHAR(9), [mapped_login_name] NVARCHAR(128), [permission_path] NVARCHAR(128));

	DECLARE @database_roles TABLE ([user_sid] VARBINARY(85),[db_name] NVARCHAR(128),[user_name] NVARCHAR(128),[role_name] NVARCHAR(128));
	DECLARE @invalid_logins TABLE ([user_sid] VARBINARY(85), [login_name] NVARCHAR(128));
	
	INSERT INTO @loginfo_cmd_list([group_sid], [logininfo_cmd])
		SELECT [sid], 'EXEC xp_logininfo @acctname = ''' + [name] + ''', @option = ''members''' FROM [master].[sys].[server_principals] WHERE [type] = 'G' AND [name] NOT LIKE 'NT SERVICE\%';
	
	OPEN loginfo_cmd_cursor
	FETCH NEXT FROM loginfo_cmd_cursor
	INTO @loginfo_sid, @loginfo_cmd;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRY
			INSERT INTO @login_info([account_name],[type],[privilege],[mapped_login_name],[permission_path])
				EXEC(@loginfo_cmd);

			UPDATE @login_info SET [group_sid] = @loginfo_sid WHERE [group_sid] IS NULL;
		END TRY
		BEGIN CATCH
			INSERT INTO @login_info VALUES(@loginfo_sid,'Error: Failed to get members.',NULL,NULL,NULL,NULL);
		END CATCH

		FETCH NEXT FROM loginfo_cmd_cursor
		INTO @loginfo_sid, @loginfo_cmd;
	END;

	INSERT INTO @invalid_logins
		EXEC [master].[dbo].[sp_validatelogins];

	INSERT INTO @database_roles
	EXEC [dbo].[foreach_db] 'USE [?];WITH [membership] ([row],[user_id],[role_id],[nest_id])
							AS
							(
								SELECT ROW_NUMBER() OVER(ORDER BY [user].[principal_id]) AS [row]
									,[user].[principal_id] AS [user_id]
									,[role].[role_principal_id] AS [role_id]
									,0 AS [nest_id]
								FROM [sys].[database_principals] [user]
									LEFT JOIN [sys].[database_role_members] AS [role]
										ON [user].[principal_id] = [role].[member_principal_id]	
								WHERE [user].[type] NOT IN (''R'') 
									AND [user].[sid] IS NOT NULL 
									AND [user].[sid] NOT IN (0x00)
									AND (([user].[type]=''S'' AND DATALENGTH([user].[sid]) <= 16) OR ([user].[type]!=''S''))
								UNION ALL
								SELECT [row]
									,[role].[member_principal_id]
									,[role].[role_principal_id]
									,[member].[nest_id]+1
								FROM [sys].[database_principals] [user]
									INNER JOIN [sys].[database_role_members] AS [role]
										ON [user].[principal_id] = [role].[member_principal_id]	
									INNER JOIN [membership] [member]
										ON [member].[role_id] = [role].[member_principal_id]
								WHERE [user].[type] IN (''R'')
							)
								SELECT [D].[sid] AS [user_sid]
									,DB_NAME() AS [db_name]
									,USER_NAME([A].[user_id]) AS [user_name]
									,USER_NAME([B].[role_id]) AS [role_name]
								FROM [membership] [A]
									INNER JOIN [membership] [B]
										ON [A].[row]=[B].[row]
									INNER JOIN sys.database_principals [D]
										ON [A].[user_id]=[D].[principal_id]
								WHERE [A].[nest_id]=0
								ORDER BY [A].[user_id],[B].[role_id];';

	SELECT [login].[name] AS [login_name]
		,ISNULL([login].[type_desc],'DB_ORPHANED') AS [login_type]
		,CAST((SELECT [account_name] FROM @login_info WHERE [group_sid]=[login].[sid] FOR XML PATH(''), ROOT('table')) AS XML) AS [group_member]
		,[login].[is_disabled] AS [is_disabled]
		,CASE WHEN [login].[type_desc] IN ('WINDOWS_LOGIN','WINDOWS_GROUP') THEN CASE WHEN [invalid].[user_sid] IS NULL THEN '0' ELSE '1' END ELSE NULL END AS [is_ad_orphaned]
		,REPLACE(REPLACE(REPLACE((SELECT SUSER_NAME([role_principal_id]) AS [data()] FROM sys.server_role_members WHERE [member_principal_id]= [login].[principal_id] FOR XML PATH('A')),'</A><A>',', '),'<A>',''),'</A>','') AS [server_roles]
		,REPLACE(REPLACE(REPLACE((SELECT [permission].[state_desc] + ' ' + [permission].[permission_name] + CASE WHEN [permission].[permission_name] = 'IMPERSONATE' THEN ' ' + QUOTENAME(SUSER_NAME([permission].[grantor_principal_id])) ELSE '' END AS [data()]
									FROM [sys].[server_permissions] [permission]
									WHERE [permission].[grantee_principal_id] = [login].[principal_id] FOR XML PATH('A')),'</A><A>',', '),'<A>',''),'</A>','') AS [server_permissions]
		,CAST((SELECT [db_name] AS [@database],[user_name] AS [@user],[role_name] AS [@role] FROM @database_roles WHERE [user_sid]=[login].[sid] ORDER BY [db_name],[user_name],[role_name] FOR XML PATH('row'), ROOT('table')) AS XML) AS [database_roles]
		,[sql_login].[is_policy_checked] AS [is_sql_login_policy_checked]
		,[sql_login].[is_expiration_checked] AS [is_sql_login_expiration_checked]
		,LOGINPROPERTY([login].[name], 'IsLocked') AS [login_locked]
		,LOGINPROPERTY([login].[name], 'LockoutTime') AS [login_lockout_time]
		,LOGINPROPERTY([login].[name], 'IsExpired') AS [login_expired]
		,LOGINPROPERTY([login].[name], 'IsMustChange') AS [must_change_password]
		,LOGINPROPERTY([login].[name], 'PasswordLastSetTime') AS [login_last_password_change]
		,LOGINPROPERTY([login].[name], 'BadPasswordCount') AS [failed_login_attempts]
	FROM sys.server_principals [login]
		LEFT JOIN sys.sql_logins [sql_login]
			ON [login].[sid] = [sql_login].[sid]
		LEFT JOIN @invalid_logins [invalid]
			ON [invalid].[user_sid] = [login].[sid]
	WHERE ([login].[type] NOT IN ('R') OR [login].[name] IS NULL)
	ORDER BY [login].[name];
END
GO