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
USE [_dbaid];
GO

DECLARE @collector_secret VARCHAR(20);
EXEC [system].[generate_secret] @length=20, @secret=@collector_secret OUT

/* Insert static variables */
MERGE INTO [system].[configuration] AS [Target] 
USING (SELECT N'INSTANCE_GUID', CAST(NEWID() AS SQL_VARIANT)
	UNION SELECT N'SANITISE_COLLECTOR_DATA',1
	UNION SELECT N'COLLECTOR_SECRET', @collector_secret
) AS [Source] ([key],[value])  
ON [Target].[key] = [Source].[key] 
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([key],[value]) 
	VALUES ([Source].[key],[Source].[value]);
GO

/* Insert wmi queries */
MERGE INTO [configg].[wmi_query] AS [Target] 
USING (VALUES('SELECT * FROM SqlService WHERE DisplayName LIKE ''%@@SERVICENAME%'' OR ServiceName = ''SQLBrowser''')
	,('SELECT * FROM ServerNetworkProtocol WHERE InstanceName LIKE ''%@@SERVICENAME%''')
	,('SELECT * FROM ServerNetworkProtocolProperty WHERE IPAddressName = ''IPAll'' AND InstanceName LIKE ''%@@SERVICENAME%''')
	,('SELECT * FROM SqlServiceAdvancedProperty WHERE ServiceName LIKE ''%@@SERVICENAME%''')
	,('SELECT * FROM ServerSettingsGeneralFlag WHERE InstanceName LIKE ''%@@SERVICENAME%''')
	,('SELECT * FROM Win32_OperatingSystem')
	,('SELECT * FROM Win32_TimeZone')
	,('SELECT * FROM win32_processor')
	,('SELECT * FROM Win32_computerSystem')
	,('SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = ''TRUE''')
	,('SELECT * FROM Win32_Volume WHERE SystemVolume <> ''TRUE'' AND DriveType <> 4 AND DriveType <> 5')
	,('SELECT * FROM Win32_GroupUser WHERE GroupComponent="Win32_Group.Domain=''@@HOSTNAME'',Name=''administrators''"')
) AS [Source] ([query])  
ON [Target].[query] = [Source].[query] 
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([query]) 
	VALUES ([Source].[query]);
GO

/* execute inventory */
EXEC [checkmk].[inventory_database];
GO
EXEC [checkmk].[inventory_agentjob];
GO

/* Create job categories */
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE [name] = N'_dbaid_ag_primary_only')
  EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'_dbaid_ag_primary_only';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE [name] = N'_dbaid_ag_secondary_only')  
  EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'_dbaid_ag_secondary_only';
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE [name] = N'_dbaid_ag_job_maintenance')
  EXEC msdb.dbo.sp_add_category @class = N'JOB', @type = N'LOCAL', @name = N'_dbaid_ag_job_maintenance';
GO

/* Create Maintenance Jobs */
USE [msdb]
GO

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
	,@JobTokenLogDir = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260))) - CHARINDEX('\',REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)))))
	,@JobTokenDateTime = N'$' + N'(ESCAPE_DQUOTE(STEPID))_' + N'$' + N'(ESCAPE_DQUOTE(STRTDT))_' + N'$' + N'(ESCAPE_DQUOTE(STRTTM))'
	,@owner = (SELECT [name] FROM sys.server_principals WHERE [sid] = 0x01)
	,@timestamp = CONVERT(VARCHAR(8), GETDATE(), 112) + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)) + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)) + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2));

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

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_config_genie')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_config_genie_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_config_genie', @new_name=@cmd, @enabled = 0;
	END 

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_config_genie', @owner_login_name=@owner,
				@enabled=0, @category_name=N'_dbaid_maintenance', @description=N'Executes the C# wmi query application to insert service information into the [_dbaid] database.', 
				@job_id = @jobId OUTPUT;

		SET @cmd = N'C:\Datacom\dbaid.configg.exe "Server=' + @JobTokenServer + ';Database=_dbaid;Trusted_Connection=True;"';

		SET @out = @JobTokenLogDir + N'\_dbaid_config_genie_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ExecConfiggExe', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_success_step_id=0, @on_fail_action=2, @on_fail_step_id=0, 
				@subsystem=N'CmdExec', @command=@cmd,
				@output_file_name=@out,
				@flags=2;

		EXEC msdb.dbo.sp_update_job @job_id=@jobId, @start_step_id=1;

		IF EXISTS (SELECT TOP(1) [schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_config_genie')
		BEGIN
			SET @schid = NULL;
			SELECT TOP(1) @schid=[schedule_id] FROM msdb.dbo.sysschedules WHERE [name] = N'_dbaid_config_genie';
			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schid
		END
		ELSE
			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_config_genie',
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=70000;

		EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
	COMMIT TRANSACTION

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_delete_system_history')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_delete_system_history_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_delete_system_history', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_delete_system_history', @owner_login_name=@owner,
				@enabled=0, @category_name=N'_dbaid_maintenance', @description=N'Executes [system].[delete_system_history] to cleanup job, backup, cmdlog history in [_dbaid] and msdb database.', 
				@job_id = @jobId OUTPUT;

		SET @out = @JobTokenLogDir + N'\_dbaid_maintenance_history_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DeleteSystemHistory', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=3, @on_fail_action=2, 
				@subsystem=N'TSQL', @command=N'EXEC [system].[delete_system_history] @job_olderthan_day=92,@backup_olderthan_day=92,@dbmail_olderthan_day=92,@maintplan_olderthan_day=92;', 
				@database_name=N'_dbaid',
				@output_file_name=@out,
				@flags=2;

		SET @cmd = N'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + @JobTokenLogDir + N'" /m "_dbaid_*.log" /d -30 2^>^&1'') do if EXIST "' + @JobTokenLogDir + N'"\%v echo del "' + @JobTokenLogDir + N'"\%v& del "' + @JobTokenLogDir + N'"\%v"'; 
				
		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DeleteLogFiles', 
				@step_id=2, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd,
				@output_file_name=@out,
				@flags=2;

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

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_full')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_backup_user_full_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_backup_user_full', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_full', @owner_login_name=@owner,
				@enabled=0, 
				@category_name=N'_dbaid_maintenance', 
				@job_id = @jobId OUTPUT;

		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
					+ N'" -d "_dbaid" -Q "EXEC [dbo].[DatabaseBackup] @Databases=''USER_DATABASES'',@BackupType=''FULL'',@CheckSum=''Y'',@CleanupTime=72" -b';
		
		SET @out = @JobTokenLogDir + N'\_dbaid_backup_user_full_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd, 
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
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=190000;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_tran')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_backup_user_tran_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_backup_user_tran', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_tran', @owner_login_name=@owner,
				@enabled=0, 
				@category_name=N'_dbaid_maintenance', 
				@job_id = @jobId OUTPUT;
				
		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
					+ N'" -d "_dbaid" -Q "EXEC [dbo].[DatabaseBackup] @Databases=''USER_DATABASES'',@BackupType=''LOG'',@CheckSum=''Y'',@CleanupTime=72" -b';

		SET @out = @JobTokenLogDir + N'\_dbaid_backup_user_tran_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd, 
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
				@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=30, @active_start_time=0;

		EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
	COMMIT TRANSACTION

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_system_full')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_backup_system_full_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_backup_system_full', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_system_full', @owner_login_name=@owner,
				@enabled=0, 
				@category_name=N'_dbaid_maintenance', 
				@job_id = @jobId OUTPUT;

		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
					+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[DatabaseBackup] @Databases=''SYSTEM_DATABASES'',@BackupType=''FULL'',@CheckSum=''Y'',@CleanupTime=72" -b';

		SET @out = @JobTokenLogDir + N'\_dbaid_backup_system_full_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd, 
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

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_index_optimise_user')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_index_optimise_user_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_index_optimise_user', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_index_optimise_user', @owner_login_name=@owner,
				@enabled=0, 
				@category_name=N'_dbaid_maintenance', 
				@job_id = @jobId OUTPUT;

		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
					+ N'" -d "_dbaid" -Q "EXEC [dbo].[IndexOptimize] @Databases=''USER_DATABASES'',@UpdateStatistics=''ALL'',@OnlyModifiedStatistics=''Y'',@StatisticsResample=''Y'',@MSShippedObjects=''Y'',@LockTimeout=600,@LogToTable=''Y''" -b';

		SET @out = @JobTokenLogDir + N'\_dbaid_index_optimise_user_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd, 
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

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_index_optimise_system')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_index_optimise_system_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_index_optimise_system', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_index_optimise_system', @owner_login_name=@owner,
				@enabled=0, 
				@category_name=N'_dbaid_maintenance', 
				@job_id = @jobId OUTPUT;

		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
					+ N'" -d "_dbaid" -Q "EXEC [dbo].[IndexOptimize] @Databases=''SYSTEM_DATABASES'',@UpdateStatistics=''ALL'',@OnlyModifiedStatistics=''Y'',@StatisticsResample=''Y'',@MSShippedObjects=''Y'',@LockTimeout=600,@LogToTable=''Y''" -b';

		SET @out = @JobTokenLogDir + N'\_dbaid_index_optimise_system_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd, 
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

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_integrity_check_user')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_integrity_check_user_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_integrity_check_user', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_integrity_check_user', @owner_login_name=@owner,
				@enabled=0, 
				@category_name=N'_dbaid_maintenance', 
				@job_id = @jobId OUTPUT;

		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
					+ N'" -d "_dbaid" -Q "EXEC [dbo].[DatabaseIntegrityCheck] @Databases=''USER_DATABASES'',@CheckCommands=''CHECKDB'',@LockTimeout=600,@LogToTable=''Y''" -b'

		SET @out = @JobTokenLogDir + N'\_dbaid_integrity_check_user_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseIntegrityCheck', 
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
				@command=@cmd, 
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

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_integrity_check_system')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_integrity_check_system_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_integrity_check_system', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_integrity_check_system', @owner_login_name=@owner,
				@enabled=0,
				@category_name=N'_dbaid_maintenance',
				@job_id = @jobId OUTPUT;

		SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
					+ N'" -d "_dbaid" -Q "EXEC [dbo].[DatabaseIntegrityCheck] @Databases=''SYSTEM_DATABASES'',@CheckCommands=''CHECKDB'',@LockTimeout=600,@LogToTable=''Y''" -b'

		SET @out = @JobTokenLogDir + N'\_dbaid_integrity_check_system_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseIntegrityCheck',
				@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec',
				@command=@cmd,
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

	SET @jobId = NULL;

	IF EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_set_ag_agent_job_state')
	BEGIN
		SET @cmd = N'__DELETE_dbaid_set_ag_agent_job_state_' + @timestamp
		EXEC msdb.dbo.sp_update_job @job_name=N'_dbaid_set_ag_agent_job_state', @new_name=@cmd, @enabled = 0;
	END

	BEGIN TRANSACTION
		EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_set_ag_agent_job_state', @owner_login_name=@owner,
				@enabled=0,
				@category_name=N'_dbaid_ag_job_maintenance',
      	@description = N'Called from "_dbaid_set_ag_agent_job_state" alert. The alert is DISABLED by default and should remain disabled if manual failover is configured as if this server is restarted, the alert detects a failover event and enables/disables the jobs. However, failover doesn''t actually occur, and the alert doesn''t detect the primary coming back online to enable/disable the jobs.',
				@job_id = @jobId OUTPUT;

		SET @cmd = N'EXEC [_dbaid].[system].[set_ag_agent_job_state] @ag_name = N''<Availability Group Name>'', @wait_seconds = 30;';

		SET @out = @JobTokenLogDir + N'\_dbaid_integrity_check_system_' + @JobTokenDateTime + N'.log';

		EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Enable or disable jobs as required',
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
GO

/* Create SQL Agent alert */
EXEC msdb.dbo.sp_add_alert @name = N'_dbaid_set_AG_agent_job_state', @message_id = 1480, @severity = 0, @enabled = 0, @delay_between_responses = 0, @include_event_description_in = 1, @job_name = N'_dbaid_set_AG_agent_job_state';
GO
