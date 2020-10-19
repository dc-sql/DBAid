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

/* #######################################################################################################################################
#	
#	Init [monitoring] database, data insert.
#
####################################################################################################################################### */
USE [$(DatabaseName)];
GO

DECLARE @installer nvarchar(128);
DECLARE @date nvarchar(25);

SET @installer = ORIGINAL_LOGIN();
SET @date = CONVERT(varchar(25), GETDATE(), 120);

/* Insert static variables */
MERGE INTO [system].[configuration] AS [Target] 
USING (SELECT N'INSTANCE_GUID', CAST(NEWID() AS sql_variant)
	UNION SELECT N'SANITISE_COLLECTOR_DATA', 1
	UNION SELECT N'COLLECTOR_SECRET', N'$(PublicKey)'
	UNION SELECT N'DBAID_VERSION_$(Version)', N'Version: $(Version)|Install Date: ' + @date + N'|Installer: ' + @installer
) AS [Source] ([key],[value])  
ON [Target].[key] = [Source].[key] 
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([key],[value]) 
	VALUES ([Source].[key],[Source].[value]);
GO

/* Insert collector procedures with NULL last_execution datetime */
MERGE INTO [collector].[last_execution] AS [Target]
USING (
	SELECT [object_name]=[name]
		,[last_execution]=NULL 
	FROM sys.objects 
	WHERE [type] = 'P' 
		AND SCHEMA_NAME([schema_id]) = N'collector'
) AS [Source]([object_name],[last_execution])
ON [Target].[object_name] = [Source].[object_name]
WHEN NOT MATCHED BY TARGET THEN 
	INSERT ([object_name],[last_execution]) VALUES ([Source].[object_name],[Source].[last_execution]);


IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Source') = 0
	EXEC sp_addextendedproperty @name = N'Source', @value = 'https://github.com/dc-sql/DBAid';
ELSE EXEC sp_updateextendedproperty @name = N'Source', @value = 'https://github.com/dc-sql/DBAid';


/* Create job categories */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE [name] = N'_dbaid_ag_primary_only')
  EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'_dbaid_ag_primary_only';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE [name] = N'_dbaid_ag_secondary_only')  
  EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'_dbaid_ag_secondary_only';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE [name] = N'_dbaid_ag_job_maintenance')
  EXEC msdb.dbo.sp_add_category @class = N'JOB', @type = N'LOCAL', @name = N'_dbaid_ag_job_maintenance';
GO


/* #######################################################################################################################################
#	
#	Apply permissions to [master] database
#
####################################################################################################################################### */
USE [master]
GO

ALTER DATABASE [$(DatabaseName)] SET MULTI_USER WITH NO_WAIT;
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [type] IN ('U','S') AND LOWER(name) = LOWER('$(CollectorServiceAccount)')) 
BEGIN
	CREATE LOGIN [$(CollectorServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
END

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE [type] IN ('U','S') AND LOWER(name) = LOWER('$(CheckServiceAccount)')) 
BEGIN
	CREATE LOGIN [$(CheckServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
END
GO

/* Instance Security */
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa] TO [$(CollectorServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa] TO [$(CheckServiceAccount)];
GRANT VIEW ANY DEFINITION TO [$(CollectorServiceAccount)];
GO

/* #######################################################################################################################################
#	
#	Apply permissions to [monitoring] database
#
####################################################################################################################################### */
USE [$(DatabaseName)];
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [type] IN ('U','S') AND LOWER(name) = LOWER('$(CollectorServiceAccount)'))
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [type] IN ('U','S') AND LOWER(name) = LOWER('$(CheckServiceAccount)'))
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO

GRANT SELECT ON [system].[configuration] TO [admin];
GRANT EXECUTE ON [checkmk].[inventory_agentjob] TO [monitor];
GRANT EXECUTE ON [checkmk].[inventory_alwayson] TO [monitor];
GRANT EXECUTE ON [checkmk].[inventory_database] TO [monitor];

/* legacy stuff, may need to enable later
--GRANT SELECT ON [dbo].[static_parameters] TO [admin];
--GRANT EXECUTE ON [maintenance].[check_config] TO [monitor];
GRANT EXECUTE ON [dbo].[insert_service] TO [admin];
GRANT EXECUTE ON [dbo].[instance_tag] TO [admin];
GRANT EXECUTE ON [dbo].[insert_service] TO [monitor];
GO
--*/

EXEC sp_addrolemember 'admin', '$(CollectorServiceAccount)';
EXEC sp_addrolemember 'monitor', '$(CheckServiceAccount)';
GO


/* #######################################################################################################################################
#	
#	Init [monitoring] database, data insert.
#
####################################################################################################################################### */
/* no version table - use system.configuration
DECLARE @installer NVARCHAR(128);
DECLARE @date NVARCHAR(25);

SET @installer = ORIGINAL_LOGIN();
SET @date = CAST(GETDATE() AS NVARCHAR(25));

IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Version') = 0
	EXEC sp_addextendedproperty @name = N'Version', @value = '$(Version)';
ELSE EXEC sp_updateextendedproperty @name = N'Version', @value = '$(Version)';
IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Source') = 0
	EXEC sp_addextendedproperty @name = N'Source', @value = 'https://github.com/dc-sql/DBAid';
ELSE EXEC sp_updateextendedproperty @name = N'Source', @value = 'https://github.com/dc-sql/DBAid';
IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Installer') = 0
	EXEC sp_addextendedproperty @name = N'Installer', @value = @installer;
ELSE EXEC sp_updateextendedproperty @name = N'Installer', @value = @installer;
IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Deployed') = 0
	EXEC sp_addextendedproperty @name = N'Deployed', @value = @date;
ELSE EXEC sp_updateextendedproperty @name = N'Deployed', @value = @date;
GO

INSERT INTO [dbo].[version]([version]) VALUES('$(Version)');
GO
--*/

/* Insert procedure list in db */
/* none of this either 
INSERT INTO [dbo].[procedure] ([procedure_id],[schema_name],[procedure_name],[description],[is_enabled],[last_execution_datetime])
	SELECT [O].[object_id] AS [procedure_id]
		,OBJECT_SCHEMA_NAME([O].[object_id]) AS [schema_name]
		,OBJECT_NAME([O].[object_id]) AS [procedure_name]
		,CASE OBJECT_SCHEMA_NAME([O].[object_id])
			WHEN 'log' THEN 'Historic log information.'
			WHEN 'report' THEN 'Meta data reports.'
			WHEN 'check' THEN 'Monitoring state checks'
			WHEN 'chart' THEN 'PnP4Nagios performance counters'
			WHEN 'deprecated' THEN '[SQLSRVPC].[DailyChecks] procedures.'
			WHEN 'fact' THEN 'configuration fact generator procedures'
			END AS [description]
		,1 AS [is_enabled]
		,NULL
	FROM [sys].[objects] [O]
		LEFT JOIN [dbo].[procedure] [P]
			ON OBJECT_SCHEMA_NAME([O].[object_id]) = [P].[schema_name]
				AND OBJECT_NAME([O].[object_id]) = [P].[procedure_name]
	WHERE [type] = 'P' AND OBJECT_SCHEMA_NAME(object_id) IN ('log','deprecated','report','check','chart','fact') 
		AND [P].[procedure_id] IS NULL
	ORDER BY OBJECT_SCHEMA_NAME(object_id), OBJECT_NAME(object_id);

-- remove reference to procedure that only works on SQL 2012 or higher.
-- shouldn't be deploying to SQL 2008 any more, but this is the only thing so far that is incompatible
IF (SELECT SERVERPROPERTY('ProductMajorVersion')) < 11
  DELETE FROM [dbo].[procedure]
  WHERE [schema_name] = 'chart'
    AND [procedure_name] = 'capacity_combined';
    
UPDATE [dbo].[procedure] SET [procedure_id] = [O].[object_id]
FROM [sys].[objects] [O]
WHERE [schema_name] = OBJECT_SCHEMA_NAME([O].[object_id])
	AND [procedure_name] = OBJECT_NAME([O].[object_id]);
GO
--*/

/* Insert static variables */
/*
-- Unique SQL Instance ID, generated during install. This GUID is used to link instance data together, please do not change.
IF NOT EXISTS(SELECT 1 FROM [system].[configuration] WHERE [key] = N'INSTANCE_GUID')
	INSERT INTO [system].[configuration]([key],[value]) 
		VALUES(N'INSTANCE_GUID', NEWID());

--This is the program name the central collector will use. Procedure last execute dates will only be updated when an application connects using this program name.
IF NOT EXISTS(SELECT 1 FROM [system].[configuration] WHERE [key] = N'PROGRAM_NAME')
	INSERT INTO [system].[configuration]([key],[value]) 
		VALUES(N'PROGRAM_NAME', 'SQL Team DBAid Collector Agent');

-- This specifies if log data should be sanitized before being written out. This will hide sensitive data, such as account and Network info
IF NOT EXISTS(SELECT 1 FROM [system].[configuration] WHERE [key] = N'SANITIZE_DATASET')
	INSERT INTO [system].[configuration]([key],[value]) 
		VALUES(N'SANITIZE_DATASET', 1);

-- Public key generated in collection server.
IF NOT EXISTS(SELECT 1 FROM [system].[configuration] WHERE [key] = N'PUBLIC_ENCRYPTION_KEY')
	INSERT INTO [system].[configuration]([key],[value]) 
		VALUES(N'PUBLIC_ENCRYPTION_KEY', N'$(PublicKey)');
--*/
/* most of this implemented as table constraints. others should probably go in system.configuration
IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'GUID')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'GUID',NEWID(),N'Unique SQL Instance ID, generated during install. This GUID is used to link instance data together, please do not change.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'PROGRAM_NAME')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'PROGRAM_NAME','(>^,^)> (SQL Team PS Collector Agent) <(^,^<)',N'This is the program name the central collector will use. Procedure last execute dates will only be updated when an applicaiton connects using this program name.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFRAG_LOG_RETENTION_DAY')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFRAG_LOG_RETENTION_DAY',90,N'The number of days to keep index defrag log data.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CAP_WARN_PERCENT')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_CAP_WARN_PERCENT',20,N'Default capacity warning percentage threshold. This is used when a new database has been setup.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CAP_CRIT_PERCENT')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_CAP_CRIT_PERCENT',10,N'Default capacity critical percentage threshold. This is used when a new database has been setup.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_JOB_MAX_MIN')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_JOB_MAX_MIN',120,N'Default job execution warning time threshold. This is used when a new job has been setup.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_JOB_STATE')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_JOB_STATE','WARNING',N'Default monitoring job state change alert');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_JOB_ENABLED')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_JOB_ENABLED',1,N'Default monitoring job alert enabled');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_DB_STATE')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_DB_STATE','CRITICAL',N'Default monitoring database state change alert');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_ALWAYSON_STATE')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_ALWAYSON_STATE','CRITICAL',N'Default alwayson availablility group state change alert');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_ALWAYSON_ROLE')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_ALWAYSON_ROLE','CRITICAL',N'Default alwayson availablility group role change alert');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'SANITIZE_DATASET')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'SANITIZE_DATASET',1,N'This specifies if log data should be sanitized before being written out. This will hide sensitive data, such as account and Network info');
GO
IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'PUBLIC_ENCRYPTION_KEY')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'PUBLIC_ENCRYPTION_KEY',N'$(PublicKey)',N'Public key generated in collection server.');
GO
IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_BACKUP_FREQ')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_BACKUP_FREQ',26,N'Default backup frequency in hours.');
GO
IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CHECKDB_FREQ')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_CHECKDB_FREQ',170,N'Default checkdb frequency in hours.');
GO
IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CHECKDB_STATE')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_CHECKDB_STATE',N'WARNING',N'Default monitoring checkdb state change alert');
GO

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_BACKUP_STATE')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'DEFAULT_BACKUP_STATE',N'WARNING',N'Default monitoring backup state change alert');
GO

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'CAPACITY_CACHE_RETENTION_MONTH')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'CAPACITY_CACHE_RETENTION_MONTH',3,N'Number of months to retain capacity cache data in log.capacity');
GO
--*/

/* General perf counters */

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Buffer Manager' AND [counter_name] = N'Page life expectancy' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:Buffer Manager',N'Page life expectancy',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Active Temp Tables' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Active Temp Tables',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Logical Connections' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Logical Connections',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Logins/sec' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Logins/sec',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Logouts/sec' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Logouts/sec',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Processes blocked' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Processes blocked',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Transactions' AND [instance_name] IS NULL)
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Transactions',NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Locks' AND [counter_name] = N'Number of Deadlocks/sec' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:Locks',N'Number of Deadlocks/sec',N'_Total');

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:SQL Errors' AND [counter_name] = N'Errors/sec' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:SQL Errors',N'Errors/sec',N'_Total');

  IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:SQL Statistics' AND [counter_name] = N'Batch Requests/Sec')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:SQL Statistics', N'Batch Requests/sec', NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:SQL Statistics' AND [counter_name] = N'SQL Compilations/sec')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:SQL Statistics', N'SQL Compilations/sec', NULL);

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Locks' AND [counter_name] = N'Average Wait Time (ms)' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Locks', N'Average Wait Time (ms)', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Locks' AND [counter_name] = N'Average Wait Time Base' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Locks', N'Average Wait Time Base', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Memory Manager' AND [counter_name] = N'Memory Grants Pending')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Memory Manager', N'Memory Grants Pending', NULL);

/* Add alwayson performance counters */
IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Availability Replica' AND [counter_name] = N'Bytes Sent to Replica/sec' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Availability Replica',N'Bytes Sent to Replica/sec',N'_Total')

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Availability Replica' AND [counter_name] = N'Bytes Received from Replica/sec' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Availability Replica',N'Bytes Received from Replica/sec',N'_Total')

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Database Replica' AND [counter_name] = N'Log Send Queue' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Database Replica',N'Log Send Queue',N'_Total')

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Database Replica' AND [counter_name] = N'Recovery Queue' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Database Replica',N'Recovery Queue',N'_Total')
GO
--*/

/* Load SQL alwayson config */
/* pretty sure this is covered by checkmk.inventory_alwayson
IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
BEGIN
	INSERT INTO [dbo].[config_alwayson]([ag_id],[ag_name],[ag_state_alert],[ag_role],[ag_role_alert])
		EXEC [dbo].[sp_executesql] @stmt = N'SELECT [AG].[ag_id]
													,[AG].[ag_name] 
													,(SELECT CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = ''DEFAULT_ALWAYSON_STATE'') AS [ag_state_alert]
													,[RS].[role_desc]
													,(SELECT CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = ''DEFAULT_ALWAYSON_ROLE'') AS [ag_role_alert]
												FROM [sys].[dm_hadr_name_id_map] [AG]
												INNER JOIN [sys].[dm_hadr_availability_replica_cluster_states] [RCS] 
													ON [RCS].[group_id] = [AG].[ag_id] 
														AND [RCS].[replica_server_name] = @@SERVERNAME
												INNER JOIN  [sys].[dm_hadr_availability_replica_states] [RS] 
													ON [RS].[group_id] = [AG].[ag_id]
														AND [RS].[replica_id] = [RCS].[replica_id]
														AND [AG].[ag_id] NOT IN (SELECT [ag_id] FROM [dbo].[config_alwayson])';

END
--*/

/* pretty sure this is covered by checkmk.inventory_database
IF ((SELECT COUNT(*) FROM [dbo].[config_database]) = 0)
BEGIN
	INSERT INTO [dbo].[config_database]
		SELECT [D].[database_id]
			,[D].[name]
			,(SELECT TOP(1) CAST([value] AS TINYINT) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CAP_WARN_PERCENT') AS [capacity_warning_percent_free]
			,(SELECT TOP(1) CAST([value] AS TINYINT) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CAP_CRIT_PERCENT') AS [capacity_critical_percent_free]
			,[M].[mirroring_role_desc]
			,CASE
				WHEN LOWER([D].[name]) IN (N'tempdb') THEN 0
				ELSE (SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_BACKUP_FREQ') 
			 END AS [backup_frequency_hours]
			 ,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = 'DEFAULT_BACKUP_STATE') AS [backup_state_alert]
			,CASE
				WHEN LOWER([D].[name]) IN (N'tempdb') THEN 0
				ELSE (SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_CHECKDB_FREQ') 
			 END AS [checkdb_frequency_hours]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = 'DEFAULT_CHECKDB_STATE') AS [checkdb_state_alert]
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = N'DEFAULT_DB_STATE') AS [change_state_alert]
			,1 AS [is_enabled]
		FROM sys.databases [D]
			LEFT JOIN sys.database_mirroring [M]
				ON [D].[database_id] = [M].[database_id]
		WHERE [D].[database_id] NOT IN (SELECT [database_id] FROM [dbo].[config_database]);
END
--*/

/* pretty sure this is covered by checkmk.inventory_agentjob
IF ((SELECT COUNT(*) FROM [dbo].[config_job]) = 0)
BEGIN
	INSERT INTO [dbo].[config_job]
		SELECT [job_id]
			,[name]
			,(SELECT CAST([value] AS TINYINT) FROM [dbo].[static_parameters] WHERE [name] = 'DEFAULT_JOB_MAX_MIN') AS [capacity_warning_percent]
			,N'WARNING' AS [default_state_alert]
			,1 AS [is_enabled]
		FROM [msdb].[dbo].[sysjobs];
END
--*/

/* Deprecated data insert start */
/* legacy daily checks
IF (SELECT COUNT([parametername]) FROM [deprecated].[tbparameters] WHERE [parametername] = 'Client_name') = 0
	INSERT INTO [deprecated].[tbparameters] ([parametername],[setting],[status],[comments])
		VALUES('Client_name','Datacom',NULL,'');
IF (SELECT COUNT([parametername]) FROM [deprecated].[tbparameters] WHERE [parametername] = 'Client_domain') = 0
	INSERT INTO [deprecated].[tbparameters] ([parametername],[setting],[status],[comments])
		VALUES('Client_domain','$(ClientDomain)',NULL,'Client domain for email addresses');

GO
--*/


/* #######################################################################################################################################
#	
#	Create agent jobs.
#
####################################################################################################################################### */
USE [msdb]
GO

DECLARE @DetectedOS NVARCHAR(7), @Slash NCHAR(1);
SET @Slash = '\'

/* sys.dm_os_host_info is relatively new (SQL 2017+ despite what BOL says; not from 2008). If it's there, query it (result being 'Linux' or 'Windows'). If not there, it's Windows. */
IF EXISTS (SELECT 1 FROM sys.system_objects WHERE [name] = N'dm_os_host_info' AND [schema_id] = SCHEMA_ID(N'sys'))
	IF ((SELECT [host_platform] FROM sys.dm_os_host_info) LIKE N'%Linux%')
	BEGIN
		SET @DetectedOS = 'Linux'
		SET @Slash = '/' /* Linux filesystems use forward slash for navigating folders, not backslash. */
	END
	ELSE IF ((SELECT SERVERPROPERTY('EngineEdition')) = 8) 
		SET @DetectedOS = 'AzureManagedInstance'
	ELSE SET @DetectedOS = 'Windows' /* If it's not Linux or Azure Managed Instance, then we assume Windows. */
ELSE 
	SELECT @DetectedOS = N'Windows'; /* if dm_os_host_info object doesn't exist, then we assume Windows. */

DECLARE @jobId BINARY(16)
	,@JobTokenServer CHAR(22)
	,@JobTokenLogDir NVARCHAR(260)
	,@JobTokenDateTime CHAR(49)
	,@cmd NVARCHAR(4000)
	,@out NVARCHAR(260)
	,@owner sysname
	,@schid INT
	,@timestamp NVARCHAR(13);

SELECT @JobTokenServer = N'$' + N'(ESCAPE_DQUOTE(SRVR))'
	,@JobTokenDateTime = N'$' + N'(ESCAPE_DQUOTE(STEPID))_' + N'$' + N'(ESCAPE_DQUOTE(STRTDT))_' + N'$' + N'(ESCAPE_DQUOTE(STRTTM))'
	,@owner = (SELECT [name] FROM sys.server_principals WHERE [sid] = 0x01)
	,@timestamp = CONVERT(VARCHAR(8), GETDATE(), 112) + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)) + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)) + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2));

SELECT @JobTokenLogDir = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260))) - CHARINDEX(@Slash,REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260))))) + @Slash;

IF ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)))) LIKE '%express%')
	PRINT 'Express Edition Detected. No SQL Agent.';
ELSE
BEGIN
	IF NOT EXISTS (SELECT [name] FROM [msdb].[dbo].[syscategories] WHERE [name] = '_dbaid_maintenance')
		EXEC msdb.dbo.sp_add_category
			@class=N'JOB',
			@type=N'LOCAL',
			@name=N'_dbaid_maintenance';

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_delete_system_history')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_delete_system_history', @owner_login_name=@owner,
			@enabled=0, @category_name=N'_dbaid_maintenance', @description=N'Executes [system].[delete_system_history] to cleanup job, backup, cmdlog history in [_dbaid] and msdb database.', 
			@job_id = @jobId OUTPUT;

		SET @out = @JobTokenLogDir + N'_dbaid_maintenance_history_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DeleteSystemHistory', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=3, @on_fail_action=2, 
			@subsystem=N'TSQL', @command=N'EXEC [system].[delete_system_history] @job_olderthan_day=92,@backup_olderthan_day=92,@dbmail_olderthan_day=92,@maintplan_olderthan_day=92;', 
			@database_name=N'_dbaid',
			@output_file_name=@out,
			@flags=2;

		/* Set step to quit with success on success if on Linux - no second job step (yet). No logs to cleanup on Azure managed instance. */
		IF @DetectedOS IN (N'Linux', N'AzureManagedInstance')
			EXEC msdb.dbo.sp_update_jobstep @job_id = @jobId, @step_id = 1, @on_success_action = 1;

		/* Not valid for Linux. Need bash equivalent. */
		IF @DetectedOS = N'Windows'
		BEGIN
			SET @cmd = N'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + @JobTokenLogDir + N'" /m "_dbaid_*.log" /d -30 2^>^&1'') do if EXIST "' + @JobTokenLogDir + N'"%v echo del "' + @JobTokenLogDir + N'"%v& del "' + @JobTokenLogDir + N'"\%v"'; 
				
			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DeleteLogFiles', 
				@step_id=2, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd,
				@output_file_name=@out,
				@flags=2;
		END

		EXEC msdb.dbo.sp_update_job @job_id=@jobId, @start_step_id=1;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_delete_system_history')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_delete_system_history';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_delete_system_history',
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=50000;

		EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF (NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_diff') AND @DetectedOS NOT IN (N'AzureManagedInstance'))
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_diff', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		/* No support for @CleanupTime parameter on Linux. */
		SELECT @cmd = N'EXEC [_dbaid].[dbo].[DatabaseBackup] @Databases=''USER_DATABASES'',@BackupType=''DIFF'',@CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N',@CleanupTime=72' ELSE N';' END;

		SELECT @out = @JobTokenLogDir + N'_dbaid_backup_user_diff_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_backup_user_diff', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
				@command=@cmd, 
				@subsystem = N'TSQL',
				@output_file_name=@out,
				@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_user_diff')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_user_diff';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_user_diff',
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=190000;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF (NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_full') AND @DetectedOS NOT IN (N'AzureManagedInstance'))
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_full', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SELECT @cmd = N'EXEC [_dbaid].[dbo].[DatabaseBackup] @Databases=''USER_DATABASES'',@BackupType=''FULL'',@CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N',@CleanupTime=72' ELSE N';' END;

		SELECT @out = @JobTokenLogDir + N'_dbaid_backup_user_full_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_backup_user_full', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
			@command=@cmd, 
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_user_full')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_user_full';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_user_full',
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=200000;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF (NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_tran') AND @DetectedOS NOT IN (N'AzureManagedInstance'))
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_tran', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SELECT @cmd = N'EXEC [_dbaid].[dbo].[DatabaseBackup] @Databases=''USER_DATABASES'',@BackupType=''LOG'',@CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N',@CleanupTime=72' ELSE N';' END;

		SELECT @out = @JobTokenLogDir + N'_dbaid_backup_user_tran_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_backup_user_tran', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
			@command=@cmd, 
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_user_tran')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_user_tran';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_user_tran',
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=15, @active_start_time=0;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF (NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_system_full') AND @DetectedOS NOT IN (N'AzureManagedInstance'))
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_system_full', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SELECT @cmd = N'EXEC [_dbaid].[dbo].[DatabaseBackup] @Databases=''SYSTEM_DATABASES'', @BackupType=''FULL'', @CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N', @CleanupTime=72' ELSE N';' END;

		SELECT @out = @JobTokenLogDir + N'_dbaid_backup_system_full_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_backup_system_full', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2,
			@command=@cmd, 
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_system_full')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_backup_system_full';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_system_full',  
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=180000;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_index_optimise_user')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_index_optimise_user', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[dbo].[IndexOptimize] @Databases=''USER_DATABASES'',@UpdateStatistics=''ALL'',@OnlyModifiedStatistics=''Y'',@StatisticsResample=''Y'',@MSShippedObjects=''Y'',@LockTimeout=600,@LogToTable=''Y''';
		SET @out = @JobTokenLogDir + N'_dbaid_index_optimise_user_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_index_optimise_user', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2,
			@command=@cmd, 
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_index_optimise_user')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_index_optimise_user';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_index_optimise_user',  
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=0, @active_start_time=0;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_index_optimise_system')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_index_optimise_system', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[dbo].[IndexOptimize] @Databases=''SYSTEM_DATABASES'',@UpdateStatistics=''ALL'',@OnlyModifiedStatistics=''Y'',@StatisticsResample=''Y'',@MSShippedObjects=''Y'',@LockTimeout=600,@LogToTable=''Y''';
		SET @out = @JobTokenLogDir + N'_dbaid_index_optimise_system_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_index_optimise_system', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
			@command=@cmd, 
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_index_optimise_system')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_index_optimise_system';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_index_optimise_system',  
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=0, @active_start_time=0;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_integrity_check_user')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_integrity_check_user', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[dbo].[DatabaseIntegrityCheck] @Databases=''USER_DATABASES'',@CheckCommands=''CHECKDB'',@LockTimeout=600,@LogToTable=''Y''';
		SET @out = @JobTokenLogDir + N'_dbaid_integrity_check_user_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_integrity_check_user', 
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
			@command=@cmd, 
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_integrity_check_user')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_integrity_check_user';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_integrity_check_user',  
				@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=40000;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_integrity_check_system')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_integrity_check_system', @owner_login_name=@owner,
			@enabled=0,
			@category_name=N'_dbaid_maintenance',
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[dbo].[DatabaseIntegrityCheck] @Databases=''SYSTEM_DATABASES'',@CheckCommands=''CHECKDB'',@LockTimeout=600,@LogToTable=''Y''';
		SET @out = @JobTokenLogDir + N'_dbaid_integrity_check_system_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_integrity_check_system',
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
			@command=@cmd,
			@subsystem = N'TSQL',
			@output_file_name=@out,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_integrity_check_system')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_integrity_check_system';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_integrity_check_system',
				@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=40000;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF (NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_set_ag_agent_job_state') AND @DetectedOS NOT IN (N'AzureManagedInstance'))
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_set_ag_agent_job_state', @owner_login_name=@owner,
			@enabled=0,
			@category_name=N'_dbaid_ag_job_maintenance',
      		@description = N'Called from "_dbaid_set_ag_agent_job_state" alert. 
				The alert and job are DISABLED by default and should remain disabled if manual failover is configured as if this server is restarted, 
				the alert detects a failover event and enables/disables the jobs. However, failover doesn''t actually occur, 
				and the alert doesn''t detect the primary coming back online to enable/disable the jobs. 
				Both the alert and this job need to be enabled for jobs to be updated after failover.',
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[system].[set_ag_agent_job_state] @ag_name = N''<Availability Group Name>'', @wait_seconds = 30;';
		SET @out = @JobTokenLogDir + N'_dbaid_integrity_check_system_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_set_ag_agent_job_state',
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'TSQL',
			@command=@cmd,
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_set_ag_agent_job_state')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_set_ag_agent_job_state';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId, @schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_set_ag_agent_job_state',
				@enabled=1, @freq_type=64, @freq_interval=0, @freq_subday_type=0, @freq_recurrence_factor=0, @active_start_time=0;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_checkmk_writelog')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_checkmk_writelog', @owner_login_name=@owner,
			@enabled=0,
			@category_name=N'_dbaid_maintenance',
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [checkmk].[inventory_agentjob]
EXEC [checkmk].[inventory_alwayson]
EXEC [checkmk].[inventory_database]
GO

EXEC [checkmk].[chart_capacity_fg] @writelog = 1
EXEC [checkmk].[check_agentjob] @writelog = 1
EXEC [checkmk].[check_alwayson] @writelog = 1
EXEC [checkmk].[check_backup] @writelog = 1
EXEC [checkmk].[check_database] @writelog = 1
EXEC [checkmk].[check_integrity] @writelog = 1
EXEC [checkmk].[check_logshipping] @writelog = 1
EXEC [checkmk].[check_mirroring] @writelog = 1
GO';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'_dbaid_checkmk_writelog',
			@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
			@database_name=N'_dbaid',
			@command=@cmd,
			@subsystem = N'TSQL',
			@flags=2;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_checkmk_writelog')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_checkmk_writelog';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_checkmk_writelog',
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=15, @active_start_time=0;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION
	END


	/* Create SQL Agent alert */
	DECLARE @alertname NVARCHAR(128);
	SELECT @alertname = [name] FROM msdb.dbo.sysalerts WHERE [message_id] = 1480;

	IF (@DetectedOS NOT IN (N'AzureManagedInstance'))
	BEGIN
		IF (@alertname IS NOT NULL)
		BEGIN
			IF (SELECT [job_id] FROM msdb.dbo.sysalerts WHERE [name]=@alertname) = '00000000-0000-0000-0000-000000000000'
				EXEC msdb.dbo.sp_update_alert @name=@alertname, @job_name=N'_dbaid_set_ag_agent_job_state'
			ELSE PRINT N'WARNING: Cannot configure Agent alert for "_dbaid_set_ag_agent_job_state", as message_id 1480 is already configured.'
		END
		ELSE IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysalerts WHERE [name] = N'_dbaid_set_ag_agent_job_state')
			EXEC msdb.dbo.sp_add_alert @name = N'_dbaid_set_ag_agent_job_state', @message_id = 1480, @severity = 0, @enabled = 0, @delay_between_responses = 0, @include_event_description_in = 1, @job_name = N'_dbaid_set_ag_agent_job_state';
	END
END

/* Update agent job history retention x10 */
IF ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)))) LIKE '%express%')
	PRINT 'Express Edition Detected. No SQL Agent.';
ELSE IF (NOT EXISTS (SELECT [login_time] FROM [sys].[dm_exec_sessions] WHERE LOWER([program_name]) LIKE 'sqlagent - generic refresher'))
	PRINT 'No SQL Agent detected. It may be stopped or disabled.';
ELSE
	EXEC [msdb].[dbo].[sp_set_sqlagent_properties] @jobhistory_max_rows=10000, @jobhistory_max_rows_per_job=1000;
GO


/* Restore Backup data from Tempdb to DBAid */
USE [$(DatabaseName)]
GO

BEGIN TRANSACTION
	DECLARE @backupsql NVARCHAR(MAX);
	DECLARE @rc INT;

	/* Restore [deprecated].[tbparameters] data */
	/* nope
	SET @backupsql = N'INSERT INTO [$(DatabaseName)].[deprecated].[tbparameters]
						SELECT [parametername],[setting],[status],[comments]
						FROM [tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]
						WHERE [parametername] COLLATE Database_Default NOT IN (SELECT [parametername] FROM [$(DatabaseName)].[deprecated].[tbparameters])';
	IF OBJECT_ID('[tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]') IS NOT NULL
	EXEC @rc = sp_executesql @stmt=@backupsql;
	--*/

	/* Restore [dbo].[config_alwayson] data */
	/* need to sort out column names
	SET @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[config_alwayson]
						SET [ag_role] = [C].[ag_role]
							,[ag_state_alert] = [C].[ag_state_alert]
							,[ag_state_is_enabled] = [C].[ag_state_is_enabled]
							,[ag_role_alert] = [C].[ag_role_alert]
							,[ag_role_is_enabled] = [C].[ag_role_is_enabled]
						FROM [$(DatabaseName)].[dbo].[config_alwayson] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_config_alwayson] [C]
								ON [O].[ag_id] = [C].[ag_id];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_alwayson') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[config_database] data */
	SELECT @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[config_database]
						SET [capacity_warning_percent_free] = [C].[capacity_warning_percent_free]
							,[capacity_critical_percent_free] = [C].[capacity_critical_percent_free]
							,[mirroring_role] = [C].[mirroring_role]
							,[change_state_alert] = [C].[change_state_alert]
							,[is_enabled] = [C].[is_enabled]'
					+	CASE WHEN EXISTS (SELECT 1 FROM [tempdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = N'$(DatabaseName)_backup_config_database' AND [COLUMN_NAME] = N'backup_frequency_hours') THEN N',[backup_frequency_hours] = [C].[backup_frequency_hours] ' ELSE N'' END
					+	CASE WHEN EXISTS (SELECT 1 FROM [tempdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = N'$(DatabaseName)_backup_config_database' AND [COLUMN_NAME] = N'checkdb_frequency_hours') THEN N',[checkdb_frequency_hours] = [C].[checkdb_frequency_hours] ' ELSE N'' END
					+	N'FROM [$(DatabaseName)].[dbo].[config_database] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_config_database] [C]
								ON [O].[database_id] = [C].[database_id];';

	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_database') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[config_job] data */
	SET @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[config_job]
						SET [max_exec_time_min] = [C].[max_exec_time_min]
							,[change_state_alert] = [C].[change_state_alert]
							,[is_enabled] = [C].[is_enabled]
						FROM [$(DatabaseName)].[dbo].[config_job] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_config_job] [C]
								ON [O].[job_id] = [C].[job_id];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_job') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [checkmk].[config_perfcounter] data */
	SET @backupsql = N'INSERT INTO [$(DatabaseName)].[checkmk].[config_perfcounter]
						SELECT [object_name],[counter_name],[instance_name],[warning_threshold],[critical_threshold]
						FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter] 
						WHERE [object_name]+[counter_name]+[instance_name] COLLATE Database_Default NOT IN (SELECT [object_name]+[counter_name]+[instance_name] FROM [$(DatabaseName)].[checkmk].[config_perfcounter]);';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	SET @backupsql = N'UPDATE [$(DatabaseName)].[checkmk].[config_perfcounter]
						SET [warning_threshold] = [C].[warning_threshold]
							,[critical_threshold] = [C].[critical_threshold]
						FROM [$(DatabaseName)].[checkmk].[config_perfcounter] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter] [C]
								ON [O].[object_name]+[O].[counter_name]+ISNULL([O].[instance_name],'''') = [C].[object_name]+[C].[counter_name]+ISNULL([C].[instance_name],'''') COLLATE Database_Default;';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[static_parameters] data */

	SET @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[static_parameters]
						SET [value] = [C].[value]
							,[description] = [C].[description]
						FROM [$(DatabaseName)].[dbo].[static_parameters] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_static_parameters] [C]
								ON [O].[name] = [C].[name] COLLATE Database_Default;';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_static_parameters') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[version] data */

	SET @backupsql = N'INSERT INTO [$(DatabaseName)].[dbo].[version]
						SELECT [version],[installer],[installdate]
						FROM [tempdb].[dbo].[$(DatabaseName)_backup_version]
						WHERE [version] COLLATE Database_Default NOT IN (SELECT [version] FROM [$(DatabaseName)].[dbo].[version])';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_version') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[procedure] data */
	SET @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[procedure]
						SET [description] = [C].[description]
							,[is_enabled] = [C].[is_enabled]
							,[last_execution_datetime] = [C].[last_execution_datetime]
						FROM [$(DatabaseName)].[dbo].[procedure] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_procedure] [C]
								ON [O].[schema_name] + [O].[procedure_name] = [C].[schema_name] + [C].[procedure_name] COLLATE Database_Default;';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_procedure') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;
--*/

PROBLEM:
IF (@@ERROR > 0 OR @rc <> 0)
BEGIN
	ROLLBACK TRANSACTION;
	PRINT 'Transaction rolled back. You will need to manually update the data from the tempdb tables.'
END
ELSE
BEGIN
	/* Cleanup tempdb tables once data has been successfully inserted / updated */
	/*
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters];';
	IF OBJECT_ID('[tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	--*/
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_alwayson];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_alwayson') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_database];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_database') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_agentjob];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_agentjob') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_configuration];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_configuration') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	/*
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_version];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_version') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_procedure];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_procedure') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	--*/
	COMMIT TRANSACTION;

	PRINT 'Transaction committed.'
END


/* execute inventory */
EXEC [checkmk].[inventory_database];
GO
EXEC [checkmk].[inventory_agentjob];
GO
EXEC [checkmk].[inventory_alwayson];
GO
