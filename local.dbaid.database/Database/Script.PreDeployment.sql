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

IF  EXISTS (SELECT * FROM master.sys.server_triggers WHERE parent_class_desc = 'SERVER' AND name = N'$(DatabaseName)_protect')
	DROP TRIGGER [$(DatabaseName)_protect] ON ALL SERVER
GO

IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=54321)
	EXEC sp_addmessage @msgnum=54321, @severity=15, @msgtext = N'Database %s dropped by user %s.';

/* Turn on blocking report*/
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;
GO

EXEC sp_configure 'blocked process threshold', 60;
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE WITH OVERRIDE;
GO

DECLARE @password NVARCHAR(50);
DECLARE @cmd NVARCHAR(180);

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(DatabaseName)_sa')) 
BEGIN
	SET @password = CAST(NEWID() AS NVARCHAR(128));
	SET @cmd = 'CREATE LOGIN [$(DatabaseName)_sa] WITH PASSWORD=N''' + @password + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=ON;';

	EXEC(@cmd);
END

EXEC master..sp_addsrvrolemember @loginame = N'$(DatabaseName)_sa', @rolename = N'sysadmin'
ALTER LOGIN [$(DatabaseName)_sa] DISABLE;
GO

USE [$(DatabaseName)]
GO

IF EXISTS (SELECT * FROM sys.triggers WHERE parent_class = 0 AND name = 'trg_stop_ddl_modification')
	DISABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE;
GO

/* set database to _dbaid_sa owner */
EXEC dbo.sp_changedbowner @loginame = N'$(DatabaseName)_sa'
GO
