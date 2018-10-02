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
	UNION SELECT N'CAPACITY_CACHE_RETENTION_MONTH',3
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

/* Create Maintenance Jobs */
USE [msdb]
GO

DECLARE @jobs TABLE([job_id] BINARY(16));
DECLARE @jobId BINARY(16);
DECLARE @JobTokenServer CHAR(22);
DECLARE @JobTokenLogDir NVARCHAR(260);
DECLARE @JobTokenDateTime CHAR(49);
DECLARE @cmd NVARCHAR(4000);
DECLARE @out NVARCHAR(260);

SET @JobTokenServer = N'$' + N'(ESCAPE_DQUOTE(SRVR))';
SELECT @JobTokenLogDir = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260))) - CHARINDEX('\',REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(260)))));
SET @JobTokenDateTime = N'$' + N'(ESCAPE_DQUOTE(STEPID))_' + N'$' + N'(ESCAPE_DQUOTE(STRTDT))_' + N'$' + N'(ESCAPE_DQUOTE(STRTTM))';

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

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_config_genie')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_config_genie', 
					@enabled=0, @category_name=N'_dbaid_maintenance', @description=N'Executes the C# wmi query application to insert service information into the [_dbaid] database.', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'C:\Datacom\dbaid.configg.exe "Server=' + @JobTokenServer + ';Database=_dbaid;Trusted_Connection=True;"';

			SET @out = @JobTokenLogDir + N'\_dbaid_config_genie_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'exec wmi load', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_success_step_id=0, @on_fail_action=2, @on_fail_step_id=0, 
					@subsystem=N'CmdExec', @command=@cmd,
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_update_job @job_id=@jobId, @start_step_id=1;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_config_genie', 
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=70000

			EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_delete_system_history')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_delete_system_history', 
					@enabled=0, @category_name=N'_dbaid_maintenance', @description=N'Executes [system].[delete_system_history] to cleanup job, backup, cmdlog history in [_dbaid] and msdb database.', 
					@job_id = @jobId OUTPUT;

			SET @out = @JobTokenLogDir + N'\_dbaid_maintenance_history_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cleanup msdb', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=3, @on_fail_action=2, 
					@subsystem=N'TSQL', @command=N'EXEC [system].[delete_system_history] @job_olderthan_day=92, @backup_olderthan_day=92, @dbmail_olderthan_day=92, @maintplan_olderthan_day=92;', 
					@database_name=N'_dbaid',
					@output_file_name=@out,
					@flags=2;

			SET @cmd = N'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + @JobTokenLogDir + N'" /m "_dbaid_*.log" /d -30 2^>^&1'') do if EXIST "' + @JobTokenLogDir + N'"\%v echo del "' + @JobTokenLogDir + N'"\%v& del "' + @JobTokenLogDir + N'"\%v"'; 
				
			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Cleanup logs', 
					@step_id=2, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd,
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_update_job @job_id=@jobId, @start_step_id=1;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_delete_system_history',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=50000

			EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_full')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_full', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @BackupType = ''FULL'', @CheckSum = ''Y'', @CleanupTime = 72" -b';
		
			SET @out = @JobTokenLogDir + N'\_dbaid_backup_user_full_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_user_full',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=190000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_user_tran')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_user_tran', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;
				
			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @BackupType = ''LOG'', @CheckSum = ''Y'', @CleanupTime = 72" -b';

			SET @out = @JobTokenLogDir + N'\_dbaid_backup_user_tran_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_user_tran',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=4, @freq_subday_interval=30, @active_start_time=0

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_backup_system_full')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_backup_system_full', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @BackupType = ''FULL'', @CheckSum = ''Y'', @CleanupTime = 72" -b';

			SET @out = @JobTokenLogDir + N'\_dbaid_backup_system_full_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Backup', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_backup_system_full',  
					@enabled=1, @freq_type=4, @freq_interval=1, @freq_subday_type=1, @active_start_time=180000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_index_optimise_user')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_index_optimise_user', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL''" -b';

			SET @out = @JobTokenLogDir + N'\_dbaid_index_optimise_user_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Optimisation', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_index_optimise_user',  
					@enabled=1, @freq_type=8, @freq_interval=64, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=02000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_index_optimise_system')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_index_optimise_system', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''SYSTEM_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL''" -b';

			SET @out = @JobTokenLogDir + N'\_dbaid_index_optimise_system_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Optimisation', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_index_optimise_system',  
					@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=0

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_integrity_check_user')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_integrity_check_user', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''USER_DATABASES'', @CheckCommands = ''CHECKDB''" -b'

			SET @out = @JobTokenLogDir + N'\_dbaid_integrity_check_user_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute CheckDB', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_integrity_check_user',  
					@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=40000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END

	SET @jobId = NULL;

	IF NOT EXISTS (SELECT [job_id] FROM [msdb].[dbo].[sysjobs_view] WHERE [name] = N'_dbaid_integrity_check_system')
	BEGIN
		BEGIN TRANSACTION
			EXEC msdb.dbo.sp_add_job @job_name=N'_dbaid_integrity_check_system', 
					@enabled=0, 
					@category_name=N'_dbaid_maintenance', 
					@job_id = @jobId OUTPUT;

			SET @cmd = N'sqlcmd -E -S "' + @JobTokenServer 
						+ N'" -d "_dbaid" -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''SYSTEM_DATABASES'', @CheckCommands = ''CHECKDB''" -b'

			SET @out = @JobTokenLogDir + N'\_dbaid_integrity_check_system_' + @JobTokenDateTime + N'.log';

			EXEC msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute CheckDB', 
					@step_id=1, @cmdexec_success_code=0, @on_success_action=1, @on_fail_action=2, @subsystem=N'CmdExec', 
					@command=@cmd, 
					@output_file_name=@out,
					@flags=2;

			EXEC msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_integrity_check_system',  
					@enabled=1, @freq_type=8, @freq_interval=1, @freq_subday_type=1, @freq_recurrence_factor=1, @active_start_time=34000

			EXEC msdb.dbo.sp_add_jobserver @job_id=@jobId, @server_name = N'(local)';
		COMMIT TRANSACTION
	END
END
GO
