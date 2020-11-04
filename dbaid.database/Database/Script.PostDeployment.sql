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
USE [_dbaid];
GO

DECLARE @installer nvarchar(128);
DECLARE @date nvarchar(25);
DECLARE @collector_secret VARCHAR(20);

/* This generates a random string of characters for use in encrypting 7z archive created by Collector */
EXEC [system].[generate_secret] @length=20, @secret=@collector_secret OUT;

SET @installer = ORIGINAL_LOGIN();
SET @date = CONVERT(varchar(25), GETDATE(), 120);

/* Insert static variables */
MERGE INTO [system].[configuration] AS [Target] 
USING (SELECT N'INSTANCE_GUID', CAST(NEWID() AS sql_variant)
	UNION SELECT N'SANITISE_COLLECTOR_DATA', 1
	UNION SELECT N'COLLECTOR_SECRET', @collector_secret
	UNION SELECT N'DBAID_VERSION_$(Version)', N'Version: $(Version) | Install Date: ' + @date + N' | Installer: ' + @installer
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

ALTER DATABASE [_dbaid] SET MULTI_USER WITH NO_WAIT;
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
GRANT IMPERSONATE ON LOGIN::[_dbaid_sa] TO [$(CollectorServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[_dbaid_sa] TO [$(CheckServiceAccount)];
GRANT VIEW ANY DEFINITION TO [$(CollectorServiceAccount)];
GO

/* #######################################################################################################################################
#	
#	Apply permissions to [monitoring] database
#
####################################################################################################################################### */
USE [_dbaid];
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
		 VALUES(N'%:Availability Replica', N'Bytes Sent to Replica/sec', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Availability Replica' AND [counter_name] = N'Bytes Received from Replica/sec' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Availability Replica', N'Bytes Received from Replica/sec', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Database Replica' AND [counter_name] = N'Log Send Queue' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Database Replica', N'Log Send Queue', N'_Total');

IF NOT EXISTS(SELECT 1 FROM [checkmk].[config_perfcounter] WHERE [object_name] = N'%:Database Replica' AND [counter_name] = N'Recovery Queue' AND [instance_name]=N'_Total')
	INSERT INTO [checkmk].[config_perfcounter]([object_name],[counter_name],[instance_name])
		 VALUES(N'%:Database Replica', N'Recovery Queue', N'_Total');
GO


/* #######################################################################################################################################
#	
#	Create agent jobs.
#
####################################################################################################################################### */
USE [msdb]
GO

DECLARE @DetectedOS NVARCHAR(7), @Slash NCHAR(1);
SET @Slash = '\';

/* sys.dm_os_host_info is relatively new (SQL 2017+ despite what BOL says; not from 2008). If it's there, query it (result being 'Linux' or 'Windows'). If not there, it's Windows. */
IF EXISTS (SELECT 1 FROM sys.system_objects WHERE [name] = N'dm_os_host_info' AND [schema_id] = SCHEMA_ID(N'sys'))
	IF ((SELECT [host_platform] FROM sys.dm_os_host_info) LIKE N'%Linux%')
	BEGIN
		SET @DetectedOS = 'Linux';
		SET @Slash = '/'; /* Linux filesystems use forward slash for navigating folders, not backslash. */
	END
	ELSE IF ((SELECT SERVERPROPERTY('EngineEdition')) = 8) 
			SET @DetectedOS = 'AzureManagedInstance';
		ELSE 
			SET @DetectedOS = 'Windows'; /* If it's not Linux or Azure Managed Instance, then we assume Windows. */
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
			@subsystem=N'TSQL', @command=N'EXEC [_dbaid].[system].[delete_system_history] @job_olderthan_day=92, @backup_olderthan_day=92, @dbmail_olderthan_day=92, @maintplan_olderthan_day=92;', 
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
		SELECT @cmd = N'EXEC [_dbaid].[dbo].[database_backup] @Databases=''USER_DATABASES'', @BackupType=''DIFF'', @CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N', @CleanupTime=72' ELSE N';' END;

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

		SELECT @cmd = N'EXEC [_dbaid].[dbo].[database_backup] @Databases=''USER_DATABASES'', @BackupType=''FULL'', @CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N', @CleanupTime=72' ELSE N';' END;

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

		SELECT @cmd = N'EXEC [_dbaid].[dbo].[database_backup] @Databases=''USER_DATABASES'', @BackupType=''LOG'', @CheckSum=''Y''' 
			+ CASE @DetectedOS WHEN N'Windows' THEN N', @CleanupTime=72' ELSE N';' END;

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

		SELECT @cmd = N'EXEC [_dbaid].[dbo].[database_backup] @Databases=''SYSTEM_DATABASES'', @BackupType=''FULL'', @CheckSum=''Y''' 
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

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_cycle_ERRORLOG')
	BEGIN
	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_cycle_ERRORLOG', @owner_login_name=@owner,
			@enabled=0, 
			@category_name=N'_dbaid_maintenance', 
			@job_id = @jobId OUTPUT;

		SET @cmd = N'DBCC ERRORLOG;'

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cycle ERRORLOG', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, 
				@command=@cmd, 
				@subsystem=N'TSQL';

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_cycle_ERRORLOG')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_cycle_ERRORLOG';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_cycle_ERRORLOG',  
				@enabled=1, @freq_type=8, @freq_interval=2, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=70000;

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

		SET @cmd = N'EXEC [_dbaid].[dbo].[index_optimize] @Databases=''USER_DATABASES'', @UpdateStatistics=''ALL'', @OnlyModifiedStatistics=''Y'', @StatisticsResample=''Y'', @MSShippedObjects=''Y'', @LockTimeout=600, @LogToTable=''Y''';
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

		SET @cmd = N'EXEC [_dbaid].[dbo].[index_optimize] @Databases=''SYSTEM_DATABASES'', @UpdateStatistics=''ALL'', @OnlyModifiedStatistics=''Y'', @StatisticsResample=''Y'', @MSShippedObjects=''Y'', @LockTimeout=600, @LogToTable=''Y''';
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

		SET @cmd = N'EXEC [_dbaid].[dbo].[integrity_check] @Databases=''USER_DATABASES'', @CheckCommands=''CHECKDB'', @LockTimeout=600, @LogToTable=''Y''';
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

		SET @cmd = N'EXEC [_dbaid].[dbo].[integrity_check] @Databases=''SYSTEM_DATABASES'', @CheckCommands=''CHECKDB'', @LockTimeout=600, @LogToTable=''Y''';
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
			@description=N'Writes CheckMK output into the SQL Server ERRORLOG. NB - will only write to ERRORLOG if there are any issues found, won''t write out anything with status of "OK".',
			@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[checkmk].[inventory_agentjob]
EXEC [_dbaid].[checkmk].[inventory_alwayson]
EXEC [_dbaid].[checkmk].[inventory_database]
GO

EXEC [_dbaid].[checkmk].[chart_capacity_fg] @writelog = 1
EXEC [_dbaid].[checkmk].[check_agentjob] @writelog = 1
EXEC [_dbaid].[checkmk].[check_alwayson] @writelog = 1
EXEC [_dbaid].[checkmk].[check_backup] @writelog = 1
EXEC [_dbaid].[checkmk].[check_database] @writelog = 1
EXEC [_dbaid].[checkmk].[check_integrity] @writelog = 1
EXEC [_dbaid].[checkmk].[check_logshipping] @writelog = 1
EXEC [_dbaid].[checkmk].[check_mirroring] @writelog = 1
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
	 ELSE IF @DetectedOS <> 'Windows'
			PRINT 'Cannot use [msdb].[dbo].[sp_set_sqlagent_properties] to set SQL Agent properties on Linux.';
		  ELSE
				EXEC [msdb].[dbo].[sp_set_sqlagent_properties] @jobhistory_max_rows=10000, @jobhistory_max_rows_per_job=1000;
GO


/* execute inventory to populate monitoring tables */
USE [_dbaid];
GO
EXEC [checkmk].[inventory_database];
GO
EXEC [checkmk].[inventory_agentjob];
GO
EXEC [checkmk].[inventory_alwayson];
GO


/* Restore Backup data from Tempdb to DBAid */
USE [_dbaid]
GO

BEGIN TRANSACTION
	DECLARE @backupsql NVARCHAR(MAX);
	DECLARE @rc INT;
	DECLARE @ver varchar(10);

	IF OBJECT_ID(N'tempdb.dbo._dbaid_Version') IS NOT NULL
		SELECT @ver = [ver] FROM [tempdb].[dbo].[_dbaid_Version];

	IF PARSENAME(@ver, 3) < 10 -- get major version; if less than 10, it's legacy DBAid, so tables & schemas are different
	BEGIN 
		/* Restore legacy [dbo].[config_alwayson] data */
		SET @backupsql = N'UPDATE [_dbaid].[checkmk].[config_alwayson]
							SET [ag_role] = [C].[ag_role]
								,[ag_state_alert] = [C].[ag_state_alert]
								,[ag_state_is_enabled] = [C].[ag_state_is_enabled]
								,[ag_role_alert] = [C].[ag_role_alert]
								,[ag_role_is_enabled] = [C].[ag_role_is_enabled]
							FROM [_dbaid].[checkmk].[config_alwayson] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_alwayson] [C]
									ON [O].[ag_name] = [C].[ag_name];';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_alwayson') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		/* Restore legacy [dbo].[config_database] data */
		SELECT @backupsql = N'UPDATE [_dbaid].[checkmk].[config_database]
							SET [capacity_check_warning_free] = [C].[capacity_warning_percent_free]
								,[capacity_check_critical_free] = [C].[capacity_critical_percent_free]
								,[mirroring_check_role] = [C].[mirroring_role]
								,[database_check_alert] = [C].[change_state_alert]
								,[database_check_enabled] = [C].[is_enabled]'
						+	CASE WHEN EXISTS (SELECT 1 FROM [tempdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = N'_dbaid_backup_config_database' AND [COLUMN_NAME] = N'backup_frequency_hours') THEN N',[backup_check_full_hour] = [C].[backup_frequency_hours] ' ELSE N'' END
						+	CASE WHEN EXISTS (SELECT 1 FROM [tempdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = N'_dbaid_backup_config_database' AND [COLUMN_NAME] = N'checkdb_frequency_hours') THEN N',[integrity_check_hour] = [C].[checkdb_frequency_hours] ' ELSE N'' END
						+	N'FROM [_dbaid].[checkmk].[config_database] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_database] [C]
									ON [O].[name] = [C].[db_name];';

		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_database') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		/* Restore legacy [dbo].[config_job] data */
		SET @backupsql = N'UPDATE [_dbaid].[checkmk].[config_agentjob]
							SET [runtime_check_min] = [C].[max_exec_time_min]
								,[state_check_alert] = [C].[change_state_alert]
								,[state_fail_check_enabled] = [C].[is_enabled]
							FROM [_dbaid].[checkmk].[config_agentjob] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_agentjob] [C]
									ON [O].[name] = [C].[job_name];';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_agentjob') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;


		/* Restore legacy [dbo].[config_perfcounter] data */
		SET @backupsql = N'INSERT INTO [_dbaid].[checkmk].[config_perfcounter]
							SELECT [object_name],[counter_name],[instance_name],[warning_threshold],[critical_threshold]
							FROM [tempdb].[dbo].[_dbaid_backup_config_perfcounter] 
							WHERE [object_name] + [counter_name] + ISNULL([instance_name], '''') COLLATE Database_Default NOT IN (SELECT [object_name] + [counter_name] + ISNULL([instance_name], '''') FROM [_dbaid].[checkmk].[config_perfcounter]);';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_perfcounter') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		SET @backupsql = N'UPDATE [_dbaid].[checkmk].[config_perfcounter]
							SET [warning_threshold] = [C].[warning_threshold]
								,[critical_threshold] = [C].[critical_threshold]
							FROM [_dbaid].[checkmk].[config_perfcounter] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_perfcounter] [C]
									ON [O].[object_name] + [O].[counter_name] + ISNULL([O].[instance_name],'''') = [C].[object_name] + [C].[counter_name] + ISNULL([C].[instance_name],'''') COLLATE Database_Default;';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_perfcounter') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;



	END
	ELSE
	BEGIN
		/* Restore [dbo].[config_alwayson] data */
		SET @backupsql = N'UPDATE [_dbaid].[checkmk].[config_alwayson]
							SET [ag_role] = [C].[ag_role]
								,[ag_state_alert] = [C].[ag_state_alert]
								,[ag_state_is_enabled] = [C].[ag_state_is_enabled]
								,[ag_role_alert] = [C].[ag_role_alert]
								,[ag_role_is_enabled] = [C].[ag_role_is_enabled]
							FROM [_dbaid].[checkmk].[config_alwayson] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_alwayson] [C]
									ON [O].[ag_name] = [C].[ag_name];';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_alwayson') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		/* Restore [dbo].[config_database] data */
		SELECT @backupsql = N'UPDATE [_dbaid].[checkmk].[config_database]
							SET [database_check_alert] = [C].[database_check_alert]
								,[database_check_enabled] = [C].[database_check_enabled]
								,[backup_check_alert] = [C].[backup_check_alert]
								,[backup_check_enabled] = [C].[backup_check_enabled]
								,[backup_check_full_hour] = [C].[backup_check_full_hour]
								,[backup_check_diff_hour] = [C].[backup_check_diff_hour]
								,[backup_check_tran_hour] = [C].[backup_check_tran_hour]
								,[integrity_check_alert] = [C].[integrity_check_alert]
								,[integrity_check_hour] = [C].[integrity_check_hour]
								,[integrity_check_enabled] = [C].[integrity_check_enabled]
								,[logshipping_check_alert] = [C].[logshipping_check_alert]
								,[logshipping_check_hour] = [C].[logshipping_check_hour]
								,[logshipping_check_enabled] = [C].[logshipping_check_enabled]
								,[mirroring_check_alert] = [C].[mirroring_check_alert]
								,[mirroring_check_role] = [C].[mirroring_check_role]
								,[mirroring_check_enabled] = [C].[mirroring_check_enabled]
								,[capacity_check_warning_free] = [C].[capacity_check_warning_free]
								,[capacity_check_critical_free] = [C].[capacity_check_critical_free]
								,[capacity_check_enabled] = [C].[capacity_check_enabled]'
						+	N'FROM [_dbaid].[dbo].[config_database] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_database] [C]
									ON [O].[name] = [C].[db_name];';

		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_database') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		/* Restore [dbo].[config_job] data */
		SET @backupsql = N'UPDATE [_dbaid].[checkmk].[config_agentjob]
							SET [state_check_alert] = [C].[state_check_alert]
								,[state_fail_check_enabled] = [C].[state_fail_check_enabled]
								,[state_cancel_check_enabled] = [C].[state_cancel_check_enabled]
								,[runtime_check_alert] = [C].[runtime_check_alert]
								,[runtime_check_min] = [C].[runtime_check_min]
								,[runtime_check_enabled] = [C].[runtime_check_enabled]
								,[is_continuous_running_job] = [C].[is_continuous_running_job]
							FROM [_dbaid].[checkmk].[config_agentjob] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_agentjob] [C]
									ON [O].[name] = [C].[job_name];';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_agentjob') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		/* Restore [checkmk].[config_perfcounter] data */
		SET @backupsql = N'INSERT INTO [_dbaid].[checkmk].[config_perfcounter]
							SELECT [object_name],[counter_name],[instance_name],[warning_threshold],[critical_threshold]
							FROM [tempdb].[dbo].[_dbaid_backup_config_perfcounter] 
							WHERE [object_name]+[counter_name]+[instance_name] COLLATE Database_Default NOT IN (SELECT [object_name]+[counter_name]+[instance_name] FROM [_dbaid].[checkmk].[config_perfcounter]);';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_perfcounter') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;

		SET @backupsql = N'UPDATE [_dbaid].[checkmk].[config_perfcounter]
							SET [warning_threshold] = [C].[warning_threshold]
								,[critical_threshold] = [C].[critical_threshold]
							FROM [_dbaid].[checkmk].[config_perfcounter] [O]
								INNER JOIN [tempdb].[dbo].[_dbaid_backup_config_perfcounter] [C]
									ON [O].[object_name]+[O].[counter_name]+ISNULL([O].[instance_name],'''') = [C].[object_name]+[C].[counter_name]+ISNULL([C].[instance_name],'''') COLLATE Database_Default;';
		IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_perfcounter') IS NOT NULL
			EXEC @rc = sp_executesql @stmt = @backupsql;

		IF (@rc <> 0) GOTO PROBLEM;
	END

PROBLEM:
IF (@@ERROR > 0 OR @rc <> 0)
BEGIN
	ROLLBACK TRANSACTION;
	PRINT 'Transaction rolled back. You will need to manually update the data from the tempdb tables.'
END
ELSE
BEGIN
	/* Cleanup tempdb tables once data has been successfully inserted / updated */
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_deprecated_tbparameters];';
	IF OBJECT_ID('[tempdb].[dbo].[_dbaid_deprecated_tbparameters]') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_static_parameters];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_static_parameters') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_version];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_version') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_procedure];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_procedure') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_configuration];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_configuration') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_config_alwayson];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_alwayson') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_config_database];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_database') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_config_agentjob];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_agentjob') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_backup_config_perfcounter];';
	IF OBJECT_ID('tempdb.dbo._dbaid_backup_config_perfcounter') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;
	SET @backupsql = N'DROP TABLE [tempdb].[dbo].[_dbaid_Version];';
	IF OBJECT_ID('tempdb.dbo._dbaid_Version') IS NOT NULL
		EXEC @rc = sp_executesql @stmt = @backupsql;

	COMMIT TRANSACTION;

	PRINT 'Transaction committed.'
END


