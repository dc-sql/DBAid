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

IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60000)
	EXEC sp_addmessage @msgnum = 60000, @severity = 16, @msgtext = N'Filegroup Capacity Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60001)
	EXEC sp_addmessage @msgnum = 60001, @severity = 16, @msgtext = N'SQL Agent Job Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60002)
	EXEC sp_addmessage @msgnum = 60002, @severity = 16, @msgtext = N'Always On Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60003)
	EXEC sp_addmessage @msgnum = 60003, @severity = 16, @msgtext = N'Backup Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60004)
	EXEC sp_addmessage @msgnum = 60004, @severity = 16, @msgtext = N'Database Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60005)
	EXEC sp_addmessage @msgnum = 60005, @severity = 16, @msgtext = N'Integrity Checks Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60006)
	EXEC sp_addmessage @msgnum = 60006, @severity = 16, @msgtext = N'Log Shipping Error: %s';
IF NOT EXISTS (SELECT 1 FROM sys.messages WHERE message_id=60007)
	EXEC sp_addmessage @msgnum = 60007, @severity = 16, @msgtext = N'DB Mirroring Error: %s';


/* Turn on blocking report*/
DECLARE @bpt INT;
SELECT @bpt = CAST([value_in_use] AS BIT) FROM sys.configurations WHERE [name] = 'blocked process threshold (s)';

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE WITH OVERRIDE;

IF @bpt = 0
BEGIN
	EXEC sp_configure 'blocked process threshold', 20;
END
GO

IF NOT EXISTS (SELECT * FROM sys.server_event_sessions WHERE [name] = N'blocking')
	CREATE EVENT SESSION [blocking] ON SERVER 
	ADD EVENT sqlserver.blocked_process_report
	ADD TARGET package0.ring_buffer(SET max_events_limit=(100))
	WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_MULTIPLE_EVENT_LOSS,STARTUP_STATE=ON);

IF NOT EXISTS (SELECT * FROM sys.dm_xe_sessions WHERE [name] = N'blocking')
	ALTER EVENT SESSION [blocking] ON SERVER STATE=START;
GO

DECLARE @password NVARCHAR(50);
DECLARE @cmd NVARCHAR(180);

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('_dbaid_sa')) 
BEGIN
	SET @password = CAST(NEWID() AS NVARCHAR(128));
	SET @cmd = 'CREATE LOGIN [_dbaid_sa] WITH PASSWORD=N''' + @password + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=ON, CHECK_POLICY=ON;';

	EXEC(@cmd);
END

EXEC master..sp_addsrvrolemember @loginame = N'_dbaid_sa', @rolename = N'sysadmin'
ALTER LOGIN [_dbaid_sa] DISABLE;
GO

USE [_dbaid];
GO

/* set database to _dbaid_sa owner */
EXEC dbo.sp_changedbowner @loginame = N'_dbaid_sa';
GO
