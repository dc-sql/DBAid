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

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(DatabaseName)_sa')) 
BEGIN
	DECLARE @cmd VARCHAR(180);
	SET @cmd = 'CREATE LOGIN [$(DatabaseName)_sa] WITH PASSWORD=N''' + CAST(NEWID() AS CHAR(38)) + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;';
	EXEC(@cmd);
	EXEC sp_addsrvrolemember @loginame = N'$(DatabaseName)_sa', @rolename = N'sysadmin';
	ALTER LOGIN [$(DatabaseName)_sa] DISABLE;
END
GO

/* set database to _dbaid_sa owner */
EXEC [$(DatabaseName)].dbo.sp_changedbowner @loginame = N'$(DatabaseName)_sa'
GO
