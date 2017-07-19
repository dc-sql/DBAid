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
USE [master]
GO
DECLARE @cmd VARCHAR(180);
SET @cmd = 'ALTER LOGIN [_dbaid_sa] WITH PASSWORD=N''' + CAST(NEWID() AS CHAR(38)) + '''';
EXEC(@cmd);
ALTER LOGIN [_dbaid_sa] DISABLE;
EXEC sp_addsrvrolemember '_dbaid_sa', 'sysadmin';
GO

USE [$(DatabaseName)];
GO

/* Insert static variables */
MERGE INTO [system].[configuration] AS [Target] 
USING (SELECT N'INSTANCE_GUID', CAST(NEWID() AS SQL_VARIANT)
	UNION SELECT N'SANITIZE_DATASET',1
	UNION SELECT N'PUBLIC_ENCRYPTION_KEY',NULL
	UNION SELECT N'CAPACITY_CACHE_RETENTION_MONTH',3
) AS [Source] ([key],[value])  
ON [Target].[key] = [Source].[key] 
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([key],[value]) 
	VALUES ([Source].[key],[Source].[value]);
GO

/* General perf counters */
MERGE INTO [checkmk].[configuration_perfmon] AS [Target] 
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
	AND ([Target].[instance_name] = [Source].[instance_name]
		OR ([Target].[instance_name] IS NULL AND [Source].[instance_name] IS NULL))
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([object_name],
			[counter_name],
			[instance_name]) 
	VALUES ([Source].[object_name],
			[Source].[counter_name],
			[Source].[instance_name]);
GO

/* execute inventory */
EXEC [checkmk].[inventory_database];
GO
EXEC [checkmk].[inventory_agentjob];
GO

