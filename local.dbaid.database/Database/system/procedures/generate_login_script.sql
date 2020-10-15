/*
Scripts logins create script.

PARAMETERS
	INPUT
		@login_name SYSNAME
		Name of the login to generate. NULL generates all logins. Default NULL. 
		
		@exclude_local BIT
		Exclude local Windows accounts. Default 1.

		@exclude_system BIT
		Exclude system accounts like ## and NT. Default 1.
*/

CREATE PROCEDURE [system].[generate_login_script] 
(
	@login_name sysname = NULL, 
	@exclude_local BIT = 1, 
	@exclude_system BIT = 1
) 
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @name sysname
		,@type CHAR(1)
		,@hasaccess INT
		,@denylogin INT
		,@is_disabled INT
		,@PWD_varbinary  VARBINARY(256)
		,@PWD_string  VARCHAR(514)
		,@SID_varbinary VARBINARY(85)
		,@SID_string VARCHAR(514)
		,@tmpstr  VARCHAR(1024)
		,@is_policy_checked VARCHAR(3)
		,@is_expiration_checked VARCHAR(3)
		,@defaultdb sysname;

	DECLARE [login_curs] CURSOR FAST_FORWARD 
	FOR	SELECT [p].[sid]
			,[p].[name]
			,[p].[type]
			,[p].[is_disabled]
			,[p].[default_database_name]
		FROM sys.server_principals [p] 
		WHERE [p].[type] IN ('S', 'G', 'U') 
			AND (([p].[name] NOT LIKE '##MS[_]%' AND [p].[name] NOT LIKE 'NT SERVICE\%' AND [p].[name] NOT LIKE 'NT AUTHORITY\%' AND [p].[sid] <> 0x01) OR @exclude_system <> 1) /* Exclude system accounts */
			AND ([p].[name] NOT LIKE CAST(SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS VARCHAR(128)) + '%' OR @exclude_local <> 1) /* Exclude local accounts */
			AND ([p].[name] = @login_name OR @login_name IS NULL);

	OPEN [login_curs];
	FETCH NEXT FROM [login_curs] INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb;

	IF (@@FETCH_STATUS = -1)
	BEGIN
		PRINT 'No login(s) found.';
		CLOSE [login_curs];
		DEALLOCATE [login_curs];
		RETURN -1;
	END

	SET @tmpstr = '/* [_dbaid].[system].[generate_login_script] ** Generated ' + CONVERT(VARCHAR, GETDATE()) + ' on ' + @@SERVERNAME + ' */';
	PRINT @tmpstr;

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		SET @tmpstr = CHAR(10) + '/*** Login: ' + @name + '***/';
		PRINT @tmpstr;
		
		SET @tmpstr = 'IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N' + @name + ') ' + CHAR(10) + CHAR(9);

		IF (@type IN ( 'G', 'U'))
		BEGIN /* NT authenticated account/group */
			SET @tmpstr = @tmpstr + 'CREATE LOGIN ' + QUOTENAME(@name) + ' FROM WINDOWS WITH DEFAULT_DATABASE = [' + @defaultdb + '] ';
		END
		ELSE 
		BEGIN /* SQL Server authentication obtain password and sid */
			SET @PWD_varbinary = CAST(LOGINPROPERTY(@name, 'PasswordHash') AS VARBINARY(256))
			SELECT @PWD_string=[hexvalue] FROM [system].[get_hexadecimal](@PWD_varbinary);
			SELECT @SID_string=[hexvalue] FROM [system].[get_hexadecimal](@SID_varbinary);

			/* obtain password policy state */
			SELECT @is_policy_checked = CASE [is_policy_checked] WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE [name] = @name;
			SELECT @is_expiration_checked = CASE [is_expiration_checked] WHEN 1 THEN 'ON' WHEN 0 THEN 'OFF' ELSE NULL END FROM sys.sql_logins WHERE [name] = @name;
 
			SET @tmpstr = @tmpstr + 'CREATE LOGIN ' + QUOTENAME(@name) + ' WITH PASSWORD = ' + @PWD_string + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + '] ';

			IF (@is_policy_checked IS NOT NULL)
				SET @tmpstr = @tmpstr + ', CHECK_POLICY = ' + @is_policy_checked;

			IF (@is_expiration_checked IS NOT NULL)
				SET @tmpstr = @tmpstr + ', CHECK_EXPIRATION = ' + @is_expiration_checked;
		END
		
		IF (@is_disabled = 1) /* login is disabled */
			SET @tmpstr = @tmpstr + '; ALTER LOGIN ' + QUOTENAME(@name) + ' DISABLE';
		
		/* Print out login create */
		PRINT @tmpstr;
		
		/* Print out login permissions */
		DECLARE [perm_curs] CURSOR FAST_FORWARD
		FOR SELECT [permission] = CASE WHEN [p].[state_desc] <> 'GRANT_WITH_GRANT_OPTION' 
				THEN [p].[state_desc]
				ELSE 'GRANT' END
				+ ' ' 
				+ [p].[permission_name] 
				+ ' TO [' 
				+ @name
				+ ']' 
				+ CASE WHEN [p].[state_desc] <> 'GRANT_WITH_GRANT_OPTION' 
					THEN ';' 
					ELSE ' WITH GRANT OPTION;'
				+ CHAR(10) END COLLATE DATABASE_DEFAULT
			FROM sys.server_permissions [p]
				INNER JOIN sys.server_principals [l]
					ON [p].[grantee_principal_id] = [l].[principal_id]
			WHERE [l].[sid] = @SID_varbinary

		OPEN [perm_curs];
		FETCH NEXT FROM [perm_curs] INTO @tmpstr;

		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			PRINT @tmpstr;
			FETCH NEXT FROM [perm_curs] INTO @tmpstr;
		END

		CLOSE [perm_curs];
		DEALLOCATE [perm_curs];

		FETCH NEXT FROM [login_curs] INTO @SID_varbinary, @name, @type, @is_disabled, @defaultdb;
	END

	CLOSE [login_curs];
	DEALLOCATE [login_curs];

	RETURN 0;
END