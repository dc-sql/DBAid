/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

/*
 Pre-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be executed before the build script.	
 Use SQLCMD syntax to include a file in the pre-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the pre-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
USE [master]
GO

/* Turn on blocking report*/
DECLARE @sao BIT, @bpt INT;
SELECT @sao = CAST([value_in_use] AS BIT) FROM sys.configurations WHERE [name] = 'show advanced options';
SELECT @bpt = CAST([value_in_use] AS BIT) FROM sys.configurations WHERE [name] = 'blocked process threshold (s)';

IF @sao = 0
BEGIN
	EXEC sp_configure 'show advanced options', 1;
	RECONFIGURE WITH OVERRIDE;
END

IF @bpt = 0
BEGIN
	EXEC sp_configure 'blocked process threshold', 60;
END

IF @sao = 0
BEGIN
	EXEC sp_configure 'show advanced options', 0;
	RECONFIGURE WITH OVERRIDE;
END
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('_dbaid_sa'))
BEGIN
	DECLARE @sql VARCHAR(500);

	DECLARE revoke_curse CURSOR FAST_FORWARD FOR
		SELECT 'REVOKE IMPERSONATE ON LOGIN::[_dbaid_sa] TO ' + QUOTENAME(SUSER_NAME(grantee_principal_id))
		FROM sys.server_permissions
		WHERE [type] = 'IM'	AND SUSER_NAME(grantor_principal_id) = '_dbaid_sa';

	OPEN revoke_curse ;
    FETCH NEXT FROM revoke_curse INTO @sql;

	WHILE @@FETCH_STATUS = 0
    BEGIN  
		EXEC(@sql);
		FETCH NEXT FROM revoke_curse INTO @sql;
	END

	CLOSE revoke_curse;
    DEALLOCATE revoke_curse;

	DROP LOGIN [_dbaid_sa];
END
GO

USE [$(DatabaseName)]
GO

