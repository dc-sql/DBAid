CREATE PROCEDURE [audit].[sql_password]
WITH ENCRYPTION
AS
BEGIN
	DECLARE @database_roles TABLE ([user_sid] VARBINARY(85),[db_name] NVARCHAR(128),[user_name] NVARCHAR(128),[role_name] NVARCHAR(128));
	DECLARE @password TABLE ([id] INT IDENTITY(1,1), [password] NVARCHAR(128) COLLATE Latin1_General_CS_AS);
	DECLARE @top INT; 

	INSERT INTO @password([password]) VALUES(N'password')
	INSERT INTO @password([password]) VALUES(N'password!')
	INSERT INTO @password([password]) VALUES(N'password@')
	INSERT INTO @password([password]) VALUES(N'password#')
	INSERT INTO @password([password]) VALUES(N'password$')
	INSERT INTO @password([password]) VALUES(N'password123')
	INSERT INTO @password([password]) VALUES(N'password1234')
	INSERT INTO @password([password]) VALUES(N'password12345')
	INSERT INTO @password([password]) VALUES(N'password123456')

	;WITH Numbers 
	AS
	(
		SELECT 0 AS [num]
		UNION ALL
		SELECT [num] + 1 AS [num]
		FROM [Numbers]
		WHERE [num] < 20
	)
	INSERT INTO @password([password]) 
	SELECT 'password' + CAST([num] AS VARCHAR(2))
	FROM Numbers

	;WITH Numbers 
	AS
	(
		SELECT 0 AS [num]
		UNION ALL
		SELECT [num] + 1 AS [num]
		FROM [Numbers]
		WHERE [num] < 9
	)
	INSERT INTO @password([password]) 
	SELECT 'password' + RIGHT('00' + CAST([num] AS VARCHAR(2)), 2)
	FROM Numbers

	;WITH Numbers 
	AS
	(
		SELECT 1990 AS [num]
		UNION ALL
		SELECT [num] + 1 AS [num]
		FROM [Numbers]
		WHERE [num] <= YEAR(GETDATE())
	)
	INSERT INTO @password([password]) 
	SELECT 'password' + CAST([num] AS CHAR(4))
	FROM Numbers

	;WITH Numbers 
	AS
	(
		SELECT CAST('19900101' AS DATE) AS [num]
		UNION ALL
		SELECT DATEADD(MONTH, 1, [num]) AS [num]
		FROM [Numbers]
		WHERE [num] <= GETDATE()
	)
	INSERT INTO @password([password])
	SELECT 'password' + CONVERT(CHAR(6), [num], 112) AS [num]
	FROM Numbers
	OPTION (MAXRECURSION 1000);

	SELECT @top = COUNT([id]) FROM @password;

	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Password') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'P@ssw0rd') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'welcome') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Welcome') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'letmein') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Letmein') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'database') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Database') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'sql') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'SQL') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'admin') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Admin') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'master') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Master') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'test') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Test') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'pass') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Pass') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'passwd') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Passwd') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'monday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Monday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'tuesday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Tuesday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'wednesday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Wednesday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'thursday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Thursday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'friday') FROM @password ORDER BY [id] ASC;
	INSERT INTO @password([password]) SELECT TOP(@top) REPLACE([password], 'password', 'Friday') FROM @password ORDER BY [id] ASC;

	INSERT INTO @database_roles
	EXEC [dbo].[foreach_db] 'USE [?]; 
		WITH [membership] ([row],[user_id],[role_id],[nest_id])
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
		,[login].[type_desc] AS [login_type]
		,[login].[is_disabled] AS [is_disabled]
		,REPLACE(REPLACE(REPLACE((SELECT SUSER_NAME([role_principal_id]) AS [data()] 
			FROM sys.server_role_members 
			WHERE [member_principal_id]= [login].[principal_id] 
			FOR XML PATH('A')),'</A><A>',', '),'<A>',''),'</A>','') AS [server_roles]
		,REPLACE(REPLACE(REPLACE((SELECT [permission].[state_desc] + ' ' + [permission].[permission_name] + 
				CASE WHEN [permission].[permission_name] = 'IMPERSONATE' 
					THEN ' ' + QUOTENAME(SUSER_NAME([permission].[grantor_principal_id])) 
					ELSE '' END AS [data()]
			FROM [sys].[server_permissions] [permission]
			WHERE [permission].[grantee_principal_id] = [login].[principal_id] 
			FOR XML PATH('A')),'</A><A>',', '),'<A>',''),'</A>','') AS [server_permissions]
		,REPLACE(REPLACE(REPLACE(REPLACE(CAST((SELECT [db_name] AS [@database],
				[user_name] AS [@user],
				ISNULL([role_name], 'public') AS [@role] 
			FROM @database_roles 
			WHERE [user_sid]=[login].[sid] 
			ORDER BY [db_name],[user_name],[role_name] 
			FOR XML PATH('row'), ROOT('table')) AS VARCHAR(4000)), '<table>', ''), '<row ', ''), '/>', ' | '), '| </table>', '') AS [database_roles]
		,[sql_login].[is_policy_checked] AS [is_sql_login_policy_checked]
		,[sql_login].[is_expiration_checked] AS [is_sql_login_expiration_checked]
		,LOGINPROPERTY([login].[name], 'IsLocked') AS [login_locked]
		,LOGINPROPERTY([login].[name], 'LockoutTime') AS [login_lockout_time]
		,LOGINPROPERTY([login].[name], 'IsExpired') AS [login_expired]
		,LOGINPROPERTY([login].[name], 'IsMustChange') AS [must_change_password]
		,LOGINPROPERTY([login].[name], 'PasswordLastSetTime') AS [login_last_password_change]
		,LOGINPROPERTY([login].[name], 'BadPasswordCount') AS [failed_login_attempts]
		,[PWD].[password]
	FROM sys.server_principals [login]
	INNER JOIN sys.sql_logins [sql_login]
		ON [login].[sid] = [sql_login].[sid]
	CROSS APPLY (SELECT [password], PWDCOMPARE([password],[sql_login].[password_hash]) FROM @password
			 UNION ALL SELECT N'', PWDCOMPARE('',[sql_login].[password_hash])
			 UNION ALL SELECT [login].[name] COLLATE Latin1_General_CS_AS, PWDCOMPARE([login].[name],[sql_login].[password_hash])  
			 UNION ALL SELECT REVERSE([login].[name]) COLLATE Latin1_General_CS_AS, PWDCOMPARE(REVERSE([login].[name]),[sql_login].[password_hash])
			 ) [PWD]([password], [match])
	WHERE [login].[type] = 'S'
		AND ([PWD].[match] = 1)
	ORDER BY [login].[name];
END
