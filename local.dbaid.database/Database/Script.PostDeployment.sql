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

ALTER DATABASE [$(DatabaseName)] SET AUTO_CLOSE OFF WITH NO_WAIT;
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)')) 
BEGIN
	CREATE LOGIN [$(CollectorServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
END

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)')) 
BEGIN
	CREATE LOGIN [$(CheckServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
END
GO

/* Instance Security */
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa]	TO [$(CollectorServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa]	TO [$(CheckServiceAccount)];
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
			WHEN 'deprecated' THEN 'Legacy DailyChecks procedures.'
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

/*
  remove reference to procedure that only works on SQL 2012 or higher.
  shouldn't be deploying to SQL 2008 any more, but this is the only thing so far that is incompatible
  ProductMajorVersion as a parameter value to SERVERPROPERTY() was introduced in SQL 2012; older versions will return NULL.
  Easier to drop the procedure here than try and code to prevent it being created in the first place.
*/
IF (SELECT SERVERPROPERTY('ProductMajorVersion')) IS NULL
  DELETE FROM [dbo].[procedure]
  WHERE [schema_name] = 'chart'
    AND [procedure_name] = 'capacity_combined';
    
UPDATE [dbo].[procedure] SET [procedure_id] = [O].[object_id]
FROM [sys].[objects] [O]
WHERE [schema_name] = OBJECT_SCHEMA_NAME([O].[object_id])
	AND [procedure_name] = OBJECT_NAME([O].[object_id]);
GO

IF (SELECT SERVERPROPERTY('ProductMajorVersion')) IS NULL AND EXISTS(SELECT 1 FROM sys.procedures WHERE [name] = N'capacity_combined' AND [schema_id] = SCHEMA_ID(N'chart'))
  DROP PROCEDURE [chart].[capacity_combined];
GO

/* Insert static variables */

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'GUID')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'GUID',NEWID(),N'Unique SQL Instance ID, generated during install. This GUID is used to link instance data together, please do not change.');

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'PROGRAM_NAME')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'PROGRAM_NAME','(>^,^)> (SQL Team PS Collector Agent) <(^,^<)',N'This is the program name the central collector will use. Procedure last execute dates will only be updated when an application connects using this program name.');

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
		VALUES(N'DEFAULT_ALWAYSON_ROLE','WARNING',N'Default alwayson availablility group role change alert');

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

IF NOT EXISTS(SELECT 1 FROM [dbo].[static_parameters] WHERE [name] = N'TENANT_NAME')
	INSERT INTO [dbo].[static_parameters]([name],[value],[description]) 
		VALUES(N'TENANT_NAME',N'$(Tenant)',N'Name of site/customer being monitored.');
GO

/* General perf counters */
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
			,(SELECT TOP(1) CAST([value] AS NVARCHAR(8)) FROM [dbo].[static_parameters] WHERE [name] = 'DEFAULT_JOB_STATE') AS [default_state_alert]
			,1 AS [is_enabled]
		FROM [msdb].[dbo].[sysjobs];
END

IF NOT EXISTS (SELECT 1 FROM [dbo].[config_login_failures] WHERE [name] = N'_dbaid_default')
BEGIN
	INSERT INTO [dbo].[config_login_failures] ([name], [failed_login_threshold], [monitoring_period_minutes])
	VALUES (N'_dbaid_default', 60, 60);
END

/* Deprecated data insert start */
IF (SELECT COUNT([parametername]) FROM [deprecated].[tbparameters] WHERE [parametername] = 'Client_name') = 0
	INSERT INTO [deprecated].[tbparameters] ([parametername],[setting],[status],[comments])
		SELECT TOP(1) 'Client_name', CAST([value] AS NVARCHAR(256)), NULL, ''
		FROM [dbo].[static_parameters] WHERE [name] = 'TENANT_NAME';
IF (SELECT COUNT([parametername]) FROM [deprecated].[tbparameters] WHERE [parametername] = 'Client_domain') = 0
	INSERT INTO [deprecated].[tbparameters] ([parametername],[setting],[status],[comments])
		VALUES('Client_domain','$(ClientDomain)',NULL,'Client domain for email addresses');

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
	SELECT [job_id] FROM [msdb].[dbo].[sysjobs] WHERE [name] IN  (N'$(DatabaseName)_service_load','$(DatabaseName)_ProcessStageAuditLogin','$(DatabaseName)_process_login');

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

	--upgrade code, remove job from older version, uses different parameters
	IF ((SELECT TOP (1) CAST(SUBSTRING([version], 0, CHARINDEX('.', [version], 0)) AS INT) FROM [_dbaid].[dbo].[version] ORDER BY [installdate] DESC) <= 4)
	BEGIN
		   EXEC msdb.dbo.sp_delete_job @job_name=N'$(DatabaseName)_maintenance_history', @delete_unused_schedule=1
	END


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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[database_backup] @Databases = ''USER_DATABASES'', @BackupType = ''FULL'', @CheckSum = ''Y'', @MaxTransferSize = 131072, @CleanupTime = 72" -b';
		
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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[database_backup] @Databases = ''USER_DATABASES'', @BackupType = ''LOG'', @CheckSum = ''Y'', @MaxTransferSize = 131072, @CleanupTime = 72" -b';

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_backup_user_tran_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_backup_user_tran',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=15, @active_start_time=0

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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[database_backup] @Databases = ''SYSTEM_DATABASES'', @BackupType = ''FULL'', @CheckSum = ''Y'', @CleanupTime = 72" -b';

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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[index_optimize] @Databases = ''USER_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL''" -b';

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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[index_optimize] @Databases = ''SYSTEM_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL''" -b';

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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[integrity_check] @Databases = ''USER_DATABASES'', @CheckCommands = ''CHECKDB''" -b'

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_integrity_check_user_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute CheckDB', 
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
						+ N'" -d "$(DatabaseName)" -Q "EXECUTE [$(DatabaseName)].[maintenance].[integrity_check] @Databases = ''SYSTEM_DATABASES'', @CheckCommands = ''CHECKDB''" -b'

			SET @out = @JobTokenLogDir + N'\$(DatabaseName)_integrity_check_system_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute CheckDB', 
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
					@command='EXEC [$(DatabaseName)].[dbo].[log_stage_capacity];', 
					@database_name=N'$(DatabaseName)', 
					@flags=0;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_log_capacity',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=73000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'$(DatabaseName)_cycle_ERRORLOG')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'$(DatabaseName)_cycle_ERRORLOG', @owner_login_name=N'$(DatabaseName)_sa',
			@enabled=0, 
			@category_name=N'_dbaid maintenance', 
			@job_id = @jobId OUTPUT;

		SET @cmd = N'DBCC ERRORLOG;'

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cycle ERRORLOG', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
				@command=@cmd, 
				@subsystem=N'TSQL';

		EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'$(DatabaseName)_cycle_ERRORLOG',  
				@enabled=1, @freq_type=8, @freq_interval=2, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=70000;

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
	SET @backupsql = N'MERGE [$(DatabaseName)].[deprecated].[tbparameters] tgt
                       USING (SELECT [parametername], [setting], [status], [comments] FROM [tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]) src ([parametername], [setting], [status], [comments])
                       ON tgt.[parametername] = src.[parametername]
                       WHEN MATCHED THEN 
                         UPDATE SET tgt.[setting] = src.[setting], tgt.[status] = src.[status], tgt.[comments] = src.[comments]
                       WHEN NOT MATCHED THEN
                         INSERT ([parametername], [setting], [status], [comments])
                         VALUES (src.[parametername], src.[setting], src.[status], src.[comments]);';
	IF OBJECT_ID('[tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters]') IS NOT NULL
	EXEC @rc = sp_executesql @stmt=@backupsql;

	/* Restore [dbo].[config_alwayson] data */
	SET @backupsql = N'MERGE [$(DatabaseName)].[dbo].[config_alwayson] tgt
                       USING (SELECT [ag_id], [ag_name], [ag_state_alert], [ag_state_is_enabled], [ag_role], [ag_role_alert], [ag_role_is_enabled] FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_alwayson]) src ([ag_id], [ag_name], [ag_state_alert], [ag_state_is_enabled], [ag_role], [ag_role_alert], [ag_role_is_enabled])
                       ON tgt.[ag_id] = src.[ag_id]
                       WHEN MATCHED THEN 
                         UPDATE SET tgt.[ag_name] = src.[ag_name], tgt.[ag_state_alert] = src.[ag_state_alert], tgt.[ag_state_is_enabled] = src.[ag_state_is_enabled], tgt.[ag_role] = src.[ag_role], tgt.[ag_role_alert] = src.[ag_role_alert], tgt.[ag_role_is_enabled] = src.[ag_role_is_enabled]
                       WHEN NOT MATCHED THEN
                         INSERT ([ag_id], [ag_name], [ag_state_alert], [ag_state_is_enabled], [ag_role], [ag_role_alert], [ag_role_is_enabled])
                         VALUES (src.[ag_id], src.[ag_name], src.[ag_state_alert], src.[ag_state_is_enabled], src.[ag_role], src.[ag_role_alert], src.[ag_role_is_enabled]);';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_alwayson') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[config_database] data */
	SELECT @backupsql = N'MERGE [$(DatabaseName)].[dbo].[config_database] tgt
                          USING (SELECT [database_id], [db_name], [capacity_warning_percent_free], [capacity_critical_percent_free], [mirroring_role], [backup_frequency_hours], [backup_state_alert], [checkdb_frequency_hours], [checkdb_state_alert], [change_state_alert] FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_database]) src ([database_id], [db_name], [capacity_warning_percent_free], [capacity_critical_percent_free], [mirroring_role], [backup_frequency_hours], [backup_state_alert], [checkdb_frequency_hours], [checkdb_state_alert], [change_state_alert])
                          ON tgt.[database_id] = src.[database_id]
                          WHEN MATCHED THEN 
                            UPDATE SET tgt.[db_name] = src.[db_name], tgt.[capacity_warning_percent_free] = src.[capacity_warning_percent_free], tgt.[capacity_critical_percent_free] = src.[capacity_critical_percent_free], tgt.[mirroring_role] = src.[mirroring_role], tgt.[backup_frequency_hours] = src.[backup_frequency_hours], tgt.[backup_state_alert] = src.[backup_state_alert], tgt.[checkdb_frequency_hours] = src.[checkdb_frequency_hours], tgt.[checkdb_state_alert] = src.[checkdb_state_alert], tgt.[change_state_alert] = src.[change_state_alert]
                          WHEN NOT MATCHED THEN
                            INSERT ([database_id], [db_name], [capacity_warning_percent_free], [capacity_critical_percent_free], [mirroring_role], [backup_frequency_hours], [backup_state_alert], [checkdb_frequency_hours], [checkdb_state_alert], [change_state_alert])
                            VALUES (src.[database_id], src.[db_name], src.[capacity_warning_percent_free], src.[capacity_critical_percent_free], src.[mirroring_role], src.[backup_frequency_hours], src.[backup_state_alert], src.[checkdb_frequency_hours], src.[checkdb_state_alert], src.[change_state_alert]);';

	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_database') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[config_job] data */
	SET @backupsql = N'MERGE [$(DatabaseName)].[dbo].[config_job] tgt
                       USING (SELECT [job_id], [job_name], [max_exec_time_min], [change_state_alert], [is_enabled] FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_job]) src ([job_id], [job_name], [max_exec_time_min], [change_state_alert], [is_enabled])
                       ON tgt.[job_id] = src.[job_id]
                       WHEN MATCHED THEN 
                         UPDATE SET tgt.[job_name] = src.[job_name], tgt.[max_exec_time_min] = src.[max_exec_time_min], tgt.[change_state_alert] = src.[change_state_alert], tgt.[is_enabled] = src.[is_enabled]
                       WHEN NOT MATCHED THEN
                         INSERT ([job_id], [job_name], [max_exec_time_min], [change_state_alert], [is_enabled])
                         VALUES (src.[job_id], src.[job_name], src.[max_exec_time_min], src.[change_state_alert], src.[is_enabled]);';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_job') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[config_login_failures] data */
	SET @backupsql = N'MERGE [$(DatabaseName)].[dbo].[config_login_failures] tgt
					   USING (SELECT [name], [failed_login_threshold], [monitoring_period_minutes], [login_failure_alert] FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_login_failures]) src ([name], [failed_login_threshold], [monitoring_period_minutes], [login_failure_alert])
                       ON (tgt.[name] = src.[name])
                       WHEN MATCHED THEN
                         UPDATE SET tgt.[failed_login_threshold] = src.[failed_login_threshold], tgt.[monitoring_period_minutes] = src.[monitoring_period_minutes], tgt.[login_failure_alert] = src.[login_failure_alert]
                       WHEN NOT MATCHED THEN
                         INSERT ([name], [failed_login_threshold], [monitoring_period_minutes], [login_failure_alert])
                         VALUES (src.[name], src.[failed_login_threshold], src.[monitoring_period_minutes], src.[login_failure_alert]);';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_login_failures') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;
	/* Restore [dbo].[config_perfcounter] data */
	SET @backupsql = N'MERGE [$(DatabaseName)].[dbo].[config_perfcounter] tgt
                       USING (SELECT [object_name], [counter_name], [instance_name], [warning_threshold], [critical_threshold] FROM [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter]) src ([object_name], [counter_name], [instance_name], [warning_threshold], [critical_threshold])
                       ON tgt.[object_name] = src.[object_name] AND tgt.[counter_name] = src.[counter_name] AND (ISNULL(tgt.[instance_name], ''NUL'') = ISNULL(src.[instance_name], ''NUL''))
                       WHEN MATCHED THEN 
                         UPDATE SET tgt.[warning_threshold] = src.[warning_threshold], tgt.[critical_threshold] = src.[critical_threshold]
                       WHEN NOT MATCHED THEN
                         INSERT ([object_name], [counter_name], [instance_name], [warning_threshold], [critical_threshold])
                       VALUES (src.[object_name], src.[counter_name], src.[instance_name], src.[warning_threshold], src.[critical_threshold]);';
	IF OBJECT_ID('tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;

	IF (@rc <> 0) GOTO PROBLEM;

	/* Restore [dbo].[static_parameters] data */
	SET @backupsql = N'MERGE [$(DatabaseName)].[dbo].[static_parameters] tgt
                       USING (SELECT [name], [value], [description] FROM [tempdb].[dbo].[$(DatabaseName)_backup_static_parameters]) src ([name], [value], [description])
                       ON tgt.[name] = src.[name]
                       WHEN MATCHED THEN 
                         UPDATE SET tgt.[value] = src.[value], tgt.[description] = src.[description]
                       WHEN NOT MATCHED THEN
                         INSERT ([name], [value], [description])
                         VALUES (src.[name], src.[value], src.[description]);';
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
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_config_alwayson]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_database];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_config_database]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_login_failures];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_config_login_failures]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_job];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_config_job]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_config_perfcounter]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_static_parameters];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_static_parameters]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_version];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_version]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[$(DatabaseName)_backup_procedure];';
	IF OBJECT_ID('tempdb.dbo.[$(DatabaseName)_backup_procedure]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt=@backupsql;
	COMMIT TRANSACTION;

	PRINT 'Transaction committed.'
END

/* Create Extended Event Session for login failure audit */
/* need to check if it exists and is running first */
IF EXISTS (SELECT 1 FROM sys.dm_xe_sessions WHERE [name] = N'_dbaid_login_failures')
  ALTER EVENT SESSION [_dbaid_login_failures] ON SERVER STATE = STOP;
GO
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE [name] = N'_dbaid_login_failures')
  DROP EVENT SESSION [_dbaid_login_failures] ON SERVER;
GO

CREATE EVENT SESSION [_dbaid_login_failures] ON SERVER 
ADD EVENT sqlserver.error_reported(
    ACTION(sqlserver.client_app_name,sqlserver.client_hostname,sqlserver.session_server_principal_name)
    WHERE ([error_number]=(18456) OR [error_number]=(18452) AND [severity]=(14) AND [state]>(1)))
ADD TARGET package0.ring_buffer
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=ON)
GO

ALTER EVENT SESSION [_dbaid_login_failures] ON SERVER STATE = START;
GO