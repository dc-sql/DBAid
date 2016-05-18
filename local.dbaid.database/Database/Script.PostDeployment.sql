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
#	Apply permissions to [master] database
#
####################################################################################################################################### */
USE [master]
GO

ALTER DATABASE [$(DatabaseName)] SET MULTI_USER WITH NO_WAIT;
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)')) 
BEGIN
	CREATE LOGIN [$(CollectorServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
END

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)')) 
BEGIN
	CREATE LOGIN [$(CheckServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
END

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([name]) = N'$(DatabaseName)' AND LOWER([type]) = 'r')
	CREATE ROLE [$(DatabaseName)];

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)')) 
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)')) 
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO

/* Instance Security */
GRANT VIEW ANY DEFINITION							TO [$(CollectorServiceAccount)];
GRANT VIEW ANY DATABASE								TO [$(CollectorServiceAccount)];
GRANT VIEW SERVER STATE								TO [$(CollectorServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa]	TO [$(CollectorServiceAccount)];

GRANT VIEW ANY DEFINITION							TO [$(CheckServiceAccount)];
GRANT VIEW ANY DATABASE								TO [$(CheckServiceAccount)];
GRANT VIEW SERVER STATE								TO [$(CheckServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa]	TO [$(CheckServiceAccount)];

/* Role security */
GRANT EXECUTE ON [dbo].[xp_logevent]			TO [public];
GRANT EXECUTE ON [dbo].[xp_enumerrorlogs]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_readerrorlog]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_readerrorlog]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_fixeddrives]			TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_logininfo]			TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_sqlagent_enum_jobs]	TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_validatelogins]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_executesql]			TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_instance_regread]	TO [$(DatabaseName)];

EXEC sp_addsrvrolemember @loginame=N'$(CollectorServiceAccount)', @rolename=N'securityadmin';
EXEC sp_addrolemember @membername=N'$(CollectorServiceAccount)', @rolename=N'$(DatabaseName)';
EXEC sp_addrolemember @membername=N'$(CheckServiceAccount)', @rolename=N'$(DatabaseName)';
GO


/* #######################################################################################################################################
#	
#	Apply permissions to [msdb] database
#
####################################################################################################################################### */
USE [msdb]
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) = 'r' AND LOWER([name]) = '$(DatabaseName)')
	CREATE ROLE [$(DatabaseName)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)'))
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)'))
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO

GRANT EXECUTE ON [dbo].[sp_help_jobhistory]	TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_help_jobactivity] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[agent_datetime] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_configure_sp] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_account_sp] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_profileaccount_sp] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_principalprofile_sp] TO [$(DatabaseName)];

GRANT SELECT ON [dbo].[log_shipping_monitor_primary] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_monitor_secondary] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_primary_secondaries] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_secondary_databases] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_secondary] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobs] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobhistory] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobschedules] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysschedules] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobactivity] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_plans] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_subplans] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_log] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_logdetail] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysproxies] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobsteps] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmail_server] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysoperators] TO [$(DatabaseName)];
GO

EXEC sp_addrolemember @membername=N'$(DatabaseName)', @rolename=N'SQLAgentReaderRole';
EXEC sp_addrolemember @membername=N'$(CollectorServiceAccount)', @rolename=N'$(DatabaseName)';
EXEC sp_addrolemember @membername=N'$(CheckServiceAccount)', @rolename=N'$(DatabaseName)';
GO


/* #######################################################################################################################################
#	
#	Apply permissions to [monitoring] database
#
####################################################################################################################################### */
USE [$(DatabaseName)];
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)'))
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)'))
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO


GRANT SELECT ON [dbo].[static_parameters] TO [admin];
GRANT EXECUTE ON [maintenance].[check_config] TO [monitor];
GRANT EXECUTE ON [dbo].[insert_service] TO [admin];
GRANT EXECUTE ON [dbo].[instance_tag] TO [admin];
GRANT EXECUTE ON [dbo].[insert_service] TO [monitor];
GO

EXEC sp_addrolemember 'admin', '$(CollectorServiceAccount)';
EXEC sp_addrolemember 'monitor', '$(CheckServiceAccount)';
GO


/* #######################################################################################################################################
#	
#	Init [monitoring] database, data insert.
#
####################################################################################################################################### */
DECLARE @installer NVARCHAR(128);
DECLARE @date NVARCHAR(25);

SET @installer = ORIGINAL_LOGIN();
SET @date = CAST(GETDATE() AS NVARCHAR(25));

IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Version') = 0
	EXEC sp_addextendedproperty @name = N'Version', @value = '$(Version)';
ELSE EXEC sp_updateextendedproperty @name = N'Version', @value = '$(Version)';
IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Source') = 0
	EXEC sp_addextendedproperty @name = N'Source', @value = 'https://dbaid.codeplex.com';
ELSE EXEC sp_updateextendedproperty @name = N'Source', @value = 'https://dbaid.codeplex.com';
IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Installer') = 0
	EXEC sp_addextendedproperty @name = N'Installer', @value = @installer;
ELSE EXEC sp_updateextendedproperty @name = N'Installer', @value = @installer;
IF (SELECT COUNT(name) FROM [sys].[extended_properties] WHERE [class] = 0 AND [name] = N'Deployed') = 0
	EXEC sp_addextendedproperty @name = N'Deployed', @value = @date;
ELSE EXEC sp_updateextendedproperty @name = N'Deployed', @value = @date;
GO

DISABLE TRIGGER [dbo].[trg_stop_version_change] ON [dbo].[version];
GO
INSERT INTO [dbo].[version]([version]) VALUES('$(Version)');
GO
ENABLE TRIGGER [dbo].[trg_stop_version_change] ON [dbo].[version];
GO
/* Insert procedure list in db */
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

UPDATE [dbo].[procedure] SET [procedure_id] = [O].[object_id]
FROM [sys].[objects] [O]
WHERE [schema_name] = OBJECT_SCHEMA_NAME([O].[object_id])
	AND [procedure_name] = OBJECT_NAME([O].[object_id]);
GO


/* Insert static variables */
DISABLE TRIGGER [dbo].[trg_stop_staticparameter_change] ON [dbo].[static_parameters];
GO

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'GUID')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'GUID',NEWID(),N'Unique SQL Instance ID, generated during install. This GUID is used to link instance data together, please do not change.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'PROGRAM_NAME')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'PROGRAM_NAME','(>^,^)> (SQL Team PS Collector Agent) <(^,^<)',N'This is the program name the central collector will use. Procedure last execute dates will only be updated when an applicaiton connects using this program name.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'AUDIT_EVENT_RETENTION_DAY')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'AUDIT_EVENT_RETENTION_DAY',7,N'The number of days to keep audit events in the audit.Event table.');

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

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'NAGIOS_EVENTHISTORY_TIMESPAN_MIN')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'NAGIOS_EVENTHISTORY_TIMESPAN_MIN',10,N'The number of minutes to show audit.event data to Nagios. After this number the events are filtered out.');

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

ENABLE TRIGGER [dbo].[trg_stop_staticparameter_change] ON [dbo].[static_parameters];
GO

/* General perf counters */
IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Broker Activation' AND [counter_name] = N'Tasks Running' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Broker Activation', N'Tasks Running', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Broker Activation' AND [counter_name] = N'Tasks Started/sec' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:Broker Activation',N'Tasks Started/sec',N'_Total');

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Broker Statistics' AND [counter_name] = N'Activation Errors Total' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:Broker Statistics',N'Activation Errors Total',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Buffer Manager' AND [counter_name] = N'Page life expectancy' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:Buffer Manager',N'Page life expectancy',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Active Temp Tables' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Active Temp Tables',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Logical Connections' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Logical Connections',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Logins/sec' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Logins/sec',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Logouts/sec' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Logouts/sec',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Processes blocked' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Processes blocked',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:General Statistics' AND [counter_name] = N'Transactions' AND [instance_name] IS NULL)
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:General Statistics',N'Transactions',NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Locks' AND [counter_name] = N'Number of Deadlocks/sec' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:Locks',N'Number of Deadlocks/sec',N'_Total');

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:SQL Errors' AND [counter_name] = N'Errors/sec' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		VALUES(N'%:SQL Errors',N'Errors/sec',N'_Total');

  IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:SQL Statistics' AND [counter_name] = N'Batch Requests/Sec')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:SQL Statistics', N'Batch Requests/sec', NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:SQL Statistics' AND [counter_name] = N'SQL Compilations/sec')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:SQL Statistics', N'SQL Compilations/sec', NULL);

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Locks' AND [counter_name] = N'Average Wait Time (ms)' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Locks', N'Average Wait Time (ms)', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Locks' AND [counter_name] = N'Average Wait Time Base' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Locks', N'Average Wait Time Base', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Memory Manager' AND [counter_name] = N'Memory Grants Pending')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name]) 
		VALUES(N'%:Memory Manager', N'Memory Grants Pending', NULL);

/* Add alwayson performance counters */
IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Availability Replica' AND [counter_name] = N'Bytes Sent to Replica/sec' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Availability Replica',N'Bytes Sent to Replica/sec',N'_Total')

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Availability Replica' AND [counter_name] = N'Bytes Received from Replica/sec' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Availability Replica',N'Bytes Received from Replica/sec',N'_Total')

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Database Replica' AND [counter_name] = N'Log Send Queue' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Database Replica',N'Log Send Queue',N'_Total')

IF NOT EXISTS(SELECT 1 FROM [dbo].[config_perfcounter] WHERE [object_name] = N'%:Database Replica' AND [counter_name] = N'Recovery Queue' AND [instance_name]=N'_Total')
	INSERT INTO [dbo].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Database Replica',N'Recovery Queue',N'_Total')
GO

/* Load SQL alwayson config */
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

/* Deprecated data insert start */
IF (SELECT COUNT([parametername]) FROM [deprecated].[tbparameters] WHERE [parametername] = 'Client_name') = 0
	INSERT INTO [deprecated].[tbparameters] ([parametername],[setting],[status],[comments])
		VALUES('Client_name','Datacom',NULL,'');
IF (SELECT COUNT([parametername]) FROM [deprecated].[tbparameters] WHERE [parametername] = 'Client_domain') = 0
	INSERT INTO [deprecated].[tbparameters] ([parametername],[setting],[status],[comments])
		VALUES('Client_domain','$(ClientDomain)',NULL,'Client domain for email addresses');

/* Enable trigger to stop ddl statements */
ENABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE;
GO


/* #######################################################################################################################################
#	
#	Create database drop trigger in [master].
#
####################################################################################################################################### */
USE [master]
GO

CREATE TRIGGER [$(DatabaseName)_protect]
ON ALL SERVER 
WITH ENCRYPTION
FOR DROP_DATABASE, ALTER_DATABASE, CREATE_DATABASE
AS
BEGIN
	SET NOCOUNT ON;
	SET ANSI_PADDING ON;

	DECLARE @user_name NVARCHAR(128);
	DECLARE @database_name NVARCHAR(128);
	DECLARE @event_type NVARCHAR(128);
	DECLARE @message NVARCHAR(500);

	SELECT @user_name= ORIGINAL_LOGIN();
	SELECT @database_name = ISNULL(EVENTDATA().value('(/EVENT_INSTANCE/DatabaseName)[1]','NVARCHAR(128)'), N'{UNKNOWN}');
	SELECT @event_type = ISNULL(EVENTDATA().value('(/EVENT_INSTANCE/EventType)[1]','NVARCHAR(128)'), N'{UNKNOWN}');

	IF @event_type IN (N'DROP_DATABASE',N'ALTER_DATABASE')
	BEGIN
		IF @database_name=N'$(DatabaseName)'
			AND EXISTS (SELECT * FROM [sys].[server_event_notifications] WHERE name IN ('DDL_SERVER_LEVEL_EVENTS','AUDIT_LOGIN','BLOCKED_PROCESS_REPORT','DEADLOCK_GRAPH','DATABASE_MIRRORING_STATE_CHANGE','DDL_DATABASE_SECURITY_EVENTS'))
		BEGIN
				RAISERROR ('You must disable the "Notification Event Services" before you DROP/ALTER the database. Please execute [$(DatabaseName)].[dbo].[Toggle_Audit_Service] passing 0 for each parameter.',10, 1);
				ROLLBACK;
				RETURN;
		END
		
		IF @event_type = N'DROP_DATABASE' 
		BEGIN
			SET @message=N'Database ' + QUOTENAME(@database_name) + N' dropped by user ' + QUOTENAME(@user_name);
			EXEC [master].[dbo].[xp_logevent] 54321, @message, 'WARNING';
		END
	END
	ELSE IF @event_type IN (N'CREATE_DATABASE')
	BEGIN
		SET @message=N'Database ' + QUOTENAME(@database_name) + N' created by user ' + QUOTENAME(@user_name);
		EXEC [master].[dbo].[xp_logevent] 54321, @message, 'WARNING';
	END
END
GO


/* #######################################################################################################################################
#	
#	Create agent job to process login audits in staging in [msdb].
#
####################################################################################################################################### */
USE [msdb]
GO

DECLARE @jobs TABLE([job_id] BINARY(16));
DECLARE @jobId BINARY(16);
DECLARE @JobTokenServer CHAR(22);
DECLARE @JobTokenLogDir NVARCHAR(260);
DECLARE @JobTokenDateTime CHAR(49);
DECLARE @cmd NVARCHAR(4000);
DECLARE @out NVARCHAR(260);

SET @JobTokenServer = N'$' + N'(ESCAPE_SQUOTE(SRVR))';
SELECT @JobTokenLogDir = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260))) - CHARINDEX('\',REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)))));
SET @JobTokenDateTime = N'$' + N'(ESCAPE_SQUOTE(STEPID))_' + N'$' + N'(ESCAPE_SQUOTE(STRTDT))_' + N'$' + N'(ESCAPE_SQUOTE(STRTTM))';

IF ((SELECT LOWER(CAST(SERVERPROPERTY('Edition') AS NVARCHAR(128)))) LIKE '%express%')
	PRINT 'Express Edition Detected. No SQL Agent.';
ELSE
BEGIN
	INSERT INTO @jobs
	SELECT [job_id] FROM [msdb].[dbo].[sysjobs] WHERE [name] IN  (N'$(DatabaseName)_service_load','$(DatabaseName)_ProcessStageAuditLogin');

	WHILE (EXISTS (SELECT [job_id] FROM @jobs))
	BEGIN
		SET @jobId = (SELECT TOP 1 [job_id] FROM @jobs);

		EXEC msdb.dbo.sp_delete_job @job_id=@jobId, @delete_unused_schedule=1;

		DELETE FROM @jobs WHERE [job_id] = @jobId;
	END

	IF NOT EXISTS (SELECT [name] FROM [msdb].[dbo].[syscategories] WHERE [name] = '_dbaid maintenance')
		EXEC msdb.dbo.sp_add_category
				@class=N'JOB',
				@type=N'LOCAL',
				@name=N'_dbaid maintenance';

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_process_login')
	BEGIN
		BEGIN TRANSACTION
			EXEC [msdb].[dbo].[sp_add_job] @job_name=N'$(DatabaseName)_process_login',@enabled=0, @category_name=N'_dbaid maintenance', 
				@description=N'Processes the login auditing staging table in the [$(DatabaseName)] database.',
				@owner_login_name=N'$(DatabaseName)_sa',@job_id=@jobId OUTPUT;

			EXEC [msdb].[dbo].[sp_add_jobstep] @job_id=@jobId, @step_name=N'Process',
				@step_id=1,@cmdexec_success_code=0,@on_success_action=1,@on_success_step_id=0,@on_fail_action=2,
				@on_fail_step_id=0,@subsystem=N'TSQL',@command=N'EXEC [process].[stageauditlogin] @batch_size=1000',@database_name=N'$(DatabaseName)';

			EXEC [msdb].[dbo].[sp_update_job] @job_id=@jobId,@start_step_id=1;

			EXEC [msdb].[dbo].[sp_add_jobschedule] @job_id=@jobId,@name=N'$(DatabaseName)_every_5min',
				@enabled=1,@freq_type=4,@freq_interval=1,@freq_subday_type=4,@freq_subday_interval=5,@freq_relative_interval=0,@freq_recurrence_factor=0,
				@active_start_date=20140101,@active_end_date=99991231,@active_start_time=0,@active_end_time=235959;

			EXEC [msdb].[dbo].[sp_add_jobserver] @job_id=@jobId,@server_name=N'(local)';
		COMMIT TRANSACTION
	END
	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_config_genie')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_config_genie', 
					@enabled=0, @category_name=N'_dbaid maintenance', @description=N'Executes the C# wmi query application to insert service information into the [_dbaid] database, then generates an asbuilt document.', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'"$(ServiceLoadExe)" -server "' + @JobTokenServer + N'" -db "$(DatabaseName)"';

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_config_genie_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'exec asbuilt', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_success_step_id=0, @on_fail_action=2, @on_fail_step_id=0, 
					@subsystem=N'CmdExec', @command=@cmd,
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_update_job @job_id=@jobId, @start_step_id=1;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_config_genie', 
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=70000

			EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_maintenance_history')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_maintenance_history', 
					@enabled=0, @category_name=N'_dbaid maintenance', @description=N'Executes [maintenance].[cleanup_history] to cleanup job, backup, cmdlog history in [$(DatabaseName)] and msdb database.', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_maintenance_history_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cleanup msdb', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=3, @on_fail_action=2, 
					@subsystem=N'TSQL', @command=N'exec [$(DatabaseName)].[maintenance].[cleanup_history] @job_olderthan_day=92, @backup_olderthan_day=92, @cmdlog_olderthan_day=92, @dbmail_olderthan_day=92, @maintplan_olderthan_day=92;', 
					@database_name=N'$(DatabaseName)',
					@output_file_name=@out,
					@flags=2;

			SET @cmd = N'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + @JobTokenLogDir + N'" /m "$(DatabaseName)_*.log" /d -30 2^>^&1'') do if EXIST "' + @JobTokenLogDir + N'"\%v echo del "' + @JobTokenLogDir + N'"\%v& del "' + @JobTokenLogDir + N'"\%v"'; 
				
			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cleanup logs', 
					@step_id=2, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd,
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_update_job @job_id=@jobId, @start_step_id=1;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_maintenance_history',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=50000

			EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_backup_user_full')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_backup_user_full', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[database_backup] @Databases = ''USER_DATABASES'', @BackupType = ''FULL'', @CheckSum = ''Y'', @CleanupTime = 72" -b';
		
			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_backup_user_full_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_backup_user_full',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=190000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_backup_user_tran')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_backup_user_tran', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;
				
			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[database_backup] @Databases = ''USER_DATABASES'', @BackupType = ''LOG'', @CheckSum = ''Y'', @CleanupTime = 72" -b';

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_backup_user_tran_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_backup_user_tran',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=30, @active_start_time=0

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_backup_system_full')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_backup_system_full', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[database_backup] @Databases = ''SYSTEM_DATABASES'', @BackupType = ''FULL'', @CheckSum = ''Y'', @CleanupTime = 72" -b';

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_backup_system_full_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_backup_system_full',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=180000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_index_optimise_user')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_index_optimise_user', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[index_optimize] @Databases = ''USER_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL''" -b';

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_index_optimise_user_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Optimisation', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_index_optimise_user',  
					@enabled=1, @freq_type=8, @freq_interval=64, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=02000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_index_optimise_system')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_index_optimise_system', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[index_optimize] @Databases = ''SYSTEM_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL''" -b';

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_index_optimise_system_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Optimisation', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_index_optimise_system',  
					@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=0

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_integrity_check_user')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_integrity_check_user', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[integrity_check] @Databases = ''USER_DATABASES'', @CheckCommands = ''CHECKDB''" -b'

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_integrity_check_user_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute CheckBD', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_integrity_check_user',  
					@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=40000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_integrity_check_system')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_integrity_check_system', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [maintenance].[integrity_check] @Databases = ''SYSTEM_DATABASES'', @CheckCommands = ''CHECKDB''" -b'

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_integrity_check_system_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute CheckBD', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_integrity_check_system',  
					@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=34000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_log_capacity')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_log_capacity', 
					@enabled=0, 
					@category_name=N'_dbaid maintenance', 
					@owner_login_name=N'$(DatabaseName)_sa', @job_id = @jobId OUTPUT;

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Log Capacity', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'TSQL', 
					@command='EXEC [dbo].[log_stage_capacity];', 
					@database_name=N'$(DatabaseName)', 
					@flags=0;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_log_capacity',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=73000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END
END
GO

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
	SET @backupsql = N'INSERT INTO [$(DatabaseName)].[deprecated].[tbparameters]
						SELECT [parametername],[setting],[status],[comments]
						FROM [tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]
						WHERE [parametername] COLLATE Database_Default NOT IN (SELECT [parametername] FROM [$(DatabaseName)].[deprecated].[tbparameters])';
	IF OBJECT_ID('[tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]') IS NOT NULL
	EXEC @rc = sp_executesql @stmt=@backupsql;

	/* Restore [dbo].[config_alwayson] data */
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

	/* Restore [dbo].[config_perfcounter] data */
	SET @backupsql = N'INSERT INTO [$(DatabaseName)].[dbo].[config_perfcounter]
						SELECT [object_name],[counter_name],[instance_name],[warning_threshold],[critical_threshold]
						FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter] 
						WHERE [object_name]+[counter_name]+[instance_name] COLLATE Database_Default NOT IN (SELECT [object_name]+[counter_name]+[instance_name] FROM [$(DatabaseName)].[dbo].[config_perfcounter]);';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	SET @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[config_perfcounter]
						SET [warning_threshold] = [C].[warning_threshold]
							,[critical_threshold] = [C].[critical_threshold]
						FROM [$(DatabaseName)].[dbo].[config_perfcounter] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter] [C]
								ON [O].[object_name]+[O].[counter_name]+[O].[instance_name] = [C].[object_name]+[C].[counter_name]+[C].[instance_name] COLLATE Database_Default;';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[static_parameters] data */
	DISABLE TRIGGER [dbo].[trg_stop_staticparameter_change] ON [dbo].[static_parameters];

	SET @backupsql = N'UPDATE [$(DatabaseName)].[dbo].[static_parameters]
						SET [value] = [C].[value]
							,[description] = [C].[description]
						FROM [$(DatabaseName)].[dbo].[static_parameters] [O]
							INNER JOIN [tempdb].[dbo].[$(DatabaseName)_backup_static_parameters] [C]
								ON [O].[name] = [C].[name] COLLATE Database_Default;';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_static_parameters') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	ENABLE TRIGGER [dbo].[trg_stop_staticparameter_change] ON [dbo].[static_parameters];

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[version] data */
	DISABLE TRIGGER [dbo].[trg_stop_version_change] ON [dbo].[version];

	SET @backupsql = N'INSERT INTO [$(DatabaseName)].[dbo].[version]
						SELECT [version],[installer],[installdate]
						FROM [tempdb].[dbo].[$(DatabaseName)_backup_version]
						WHERE [version] COLLATE Database_Default NOT IN (SELECT [version] FROM [$(DatabaseName)].[dbo].[version])';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_version') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	ENABLE TRIGGER [dbo].[trg_stop_version_change] ON [dbo].[version];

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

PROBLEM:
IF (@@ERROR > 0 OR @rc <> 0)
BEGIN
	ROLLBACK TRANSACTION;
	PRINT 'Transaction rolled back. You will need to manually update the data from the tempdb tables.'
END
ELSE
BEGIN
	/* Cleanup tempdb tables once data has been successfully inserted / updated */
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters];';
	IF OBJECT_ID('[tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_alwayson];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_alwayson') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_database];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_database') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_job];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_job') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_static_parameters];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_static_parameters') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_version];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_version') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_procedure];';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_procedure') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	COMMIT TRANSACTION;

	PRINT 'Transaction committed.'
END