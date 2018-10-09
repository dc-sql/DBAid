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
	EXEC sp_configure 'blocked process threshold', 20;
END

IF @sao = 0
BEGIN
	EXEC sp_configure 'show advanced options', 0;
	RECONFIGURE WITH OVERRIDE;
END
GO

IF NOT EXISTS (SELECT * FROM sys.server_event_sessions WHERE [name] = N'blocking')
	CREATE EVENT SESSION [blocking] ON SERVER 
	ADD EVENT sqlserver.blocked_process_report
	ADD TARGET package0.ring_buffer(SET max_events_limit=(100))
	WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_MULTIPLE_EVENT_LOSS,STARTUP_STATE=ON)

IF NOT EXISTS (SELECT * FROM sys.dm_xe_sessions WHERE [name] = N'blocking')
	ALTER EVENT SESSION [blocking] ON SERVER STATE=START;

IF NOT EXISTS (SELECT * FROM sys.dm_xe_sessions WHERE [name] = N'system_health')
	ALTER EVENT SESSION [system_health] ON SERVER STATE=START;

USE [_dbaid]
GO

