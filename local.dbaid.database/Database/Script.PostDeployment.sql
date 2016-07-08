/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

USE [$(DatabaseName)];
GO

INSERT INTO [setting].[check_state] 
VALUES(1, N'CRITICAL', N'Generally raised as a service desk P2'),
(2, N'WARNING', N'Generally raised as a service desk P3'),
(3, N'OK', N'Default state for all green, everything is OK');

/* Insert static variables */
MERGE INTO [setting].[static_parameters] AS [Target] 
USING (VALUES(N'GUID',NEWID(),N'Unique SQL Instance ID, generated during install. This GUID is used to link instance data together, please do not change.')
	,(N'PROGRAM_NAME','(>^,^)> (SQL Team PS Collector Agent) <(^,^<)',N'This is the program name the central collector will use. Procedure last execute dates will only be updated when an applicaiton connects using this program name.')
	,(N'AUDIT_EVENT_RETENTION_DAY',7,N'The number of days to keep audit events in the audit.Event table.')
	,(N'DEFRAG_LOG_RETENTION_DAY',90,N'The number of days to keep index defrag log data.')
	,(N'DEFAULT_CAP_WARN_PERCENT',20,N'Default capacity warning percentage threshold. This is used when a new database has been setup.')
	,(N'DEFAULT_CAP_CRIT_PERCENT',10,N'Default capacity critical percentage threshold. This is used when a new database has been setup.')
	,(N'DEFAULT_JOB_MAX_MIN',120,N'Default job execution warning time threshold. This is used when a new job has been setup.')
	,(N'DEFAULT_JOB_STATE','WARNING',N'Default monitoring job state change alert')
	,(N'DEFAULT_JOB_ENABLED',1,N'Default monitoring job alert enabled')
	,(N'DEFAULT_DB_STATE','CRITICAL',N'Default monitoring database state change alert')
	,(N'DEFAULT_ALWAYSON_STATE','CRITICAL',N'Default alwayson availablility group state change alert')
	,(N'DEFAULT_ALWAYSON_ROLE','CRITICAL',N'Default alwayson availablility group role change alert')
	,(N'NAGIOS_EVENTHISTORY_TIMESPAN_MIN',10,N'The number of minutes to show audit.event data to Nagios. After this number the events are filtered out.')
	,(N'SANITIZE_DATASET',1,N'This specifies if log data should be sanitized before being written out. This will hide sensitive data, such as account and Network info')
	,(N'PUBLIC_ENCRYPTION_KEY',N'$(PublicKey)',N'Public key generated in collection server.')
	,(N'DEFAULT_BACKUP_FREQ',26,N'Default backup frequency in hours.')
	,(N'DEFAULT_CHECKDB_FREQ',170,N'Default checkdb frequency in hours.')
	,(N'DEFAULT_CHECKDB_STATE',N'WARNING',N'Default monitoring checkdb state change alert')
	,(N'DEFAULT_BACKUP_STATE',N'WARNING',N'Default monitoring backup state change alert')
	,(N'CAPACITY_CACHE_RETENTION_MONTH',3,N'Number of months to retain capacity cache data in log.capacity')
) AS [Source] ([name],[value],[description])  
ON [Target].[name] = [Source].[name] 
WHEN NOT MATCHED BY TARGET THEN  
INSERT ([name],[value],[description]) 
VALUES ([Source].[name],[Source].[value],[Source].[description]);
GO

/* General perf counters */
MERGE INTO [setting].[chart_perfcounter] AS [Target] 
USING (VALUES(N'%:Broker Activation', N'Tasks Running', N'_Total')
	,(N'%:Broker Activation',N'Tasks Started/sec',N'_Total')
	,(N'%:Broker Statistics',N'Activation Errors Total',NULL)
	,(N'%:Buffer Manager',N'Page life expectancy',NULL)
	,(N'%:General Statistics',N'Active Temp Tables',NULL)
	,(N'%:General Statistics',N'Logical Connections',NULL)
	,(N'%:General Statistics',N'Logins/sec',NULL)
	,(N'%:General Statistics',N'Logouts/sec',NULL)
	,(N'%:General Statistics',N'Processes blocked',NULL)
	,(N'%:General Statistics',N'Transactions',NULL)
	,(N'%:Locks',N'Number of Deadlocks/sec',N'_Total')
	,(N'%:SQL Errors',N'Errors/sec',N'_Total')
	,(N'%:SQL Statistics', N'Batch Requests/sec', NULL)
	,(N'%:SQL Statistics', N'SQL Compilations/sec', NULL)
	,(N'%:Locks', N'Average Wait Time (ms)', N'_Total')
	,(N'%:Locks', N'Average Wait Time Base', N'_Total')
	,(N'%:Memory Manager', N'Memory Grants Pending', NULL)
	,(N'%:Availability Replica',N'Bytes Sent to Replica/sec',N'_Total')
	,(N'%:Availability Replica',N'Bytes Received from Replica/sec',N'_Total')
	,(N'%:Database Replica',N'Log Send Queue',N'_Total')
	,(N'%:Database Replica',N'Recovery Queue',N'_Total')
) AS [Source] ([object_name],[counter_name],[instance_name])  
ON [Target].[object_name] = [Source].[object_name] 
	AND [Target].[counter_name] = [Source].[counter_name] 
	AND [Target].[instance_name] = [Source].[instance_name] 
WHEN NOT MATCHED BY TARGET THEN  
INSERT ([object_name],[counter_name],[instance_name]) 
VALUES ([Source].[object_name],[Source].[counter_name],[Source].[instance_name]);
GO

/* execute dbaid inventory */
EXEC [dbo].[dbaid_inventory];
GO


