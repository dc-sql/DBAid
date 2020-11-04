/*
Create SQL Agent job to load XML files into _dbaid_warehouse
*/
USE [msdb];
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT;
SELECT @ReturnCode = 0;

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'_dbaid_warehouse' AND category_class=1)
BEGIN
  EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'_dbaid_warehouse';
  IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
END

DECLARE @jobId BINARY(16);
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'_dbaid_warehouse_load', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'_dbaid_warehouse', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load instance configuration', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Param (
    [parameter()]
    [string]$WarehouseServer = ''servername'',

    [parameter()]
    [string]$WarehouseDatabase = ''_dbaid_warehouse'',

    [parameter()]
    [System.String]$InputXmlRootPath = ''PathToXmlFilesToLoad''

)
$XMLPattern = ''*get_instance_ci*.xml''
$XMLFullFilePath = Join-Path $InputXmlRootPath $XMLPattern

$XMLFilelist = Get-ChildItem $XMLFullFilePath

foreach ($XMLFile in $XMLFileList) {
    $SqlQuery = ''DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '''''' + $XMLFile + '''''', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_instance] ([instance_guid], [datetimeoffset], [property], [value])
  SELECT *
  FROM OPENXML(@hdoc, ''''//DocumentElement/get_instance_ci'''')
  WITH (
    [instance_guid] uniqueidentifier ''''instance_guid'''',
    [datetimeoffset] datetime2 ''''datetimeoffset'''',
    [property] sysname ''''property'''',
    [value] sql_variant ''''value''''
  );

EXEC sp_xml_removedocument @hdoc;
GO''

    Invoke-Sqlcmd -ServerInstance $WarehouseServer -Database $WarehouseDatabase -Query $SqlQuery
}', 
		@database_name=N'master', 
		@flags=0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load database configuration', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Param (
    [parameter()]
    [string]$WarehouseServer = ''servername'',

    [parameter()]
    [string]$WarehouseDatabase = ''_dbaid_warehouse'',

    [parameter()]
    [System.String]$InputXmlRootPath = ''PathToXmlFilesToLoad''

)
$XMLPattern = ''*get_database_ci*.xml''
$XMLFullFilePath = Join-Path $InputXmlRootPath $XMLPattern

$XMLFilelist = Get-ChildItem $XMLFullFilePath

foreach ($XMLFile in $XMLFileList) {
    $SqlQuery = ''DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '''''' + $XMLFile + '''''', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_db] ([instance_guid], [datetimeoffset], [database_name], [property], [value])
  SELECT *
  FROM OPENXML(@hdoc, ''''//DocumentElement/get_database_ci'''')
  WITH (
    [instance_guid] uniqueidentifier ''''instance_guid'''',
    [datetimeoffset] datetime2 ''''datetimeoffset'''',
    [database_name] sysname ''''name'''',
    [property] sysname ''''property'''',
    [value] sql_variant ''''value''''
  );

EXEC sp_xml_removedocument @hdoc;
GO''

    Invoke-Sqlcmd -ServerInstance $WarehouseServer -Database $WarehouseDatabase -Query $SqlQuery
}', 
		@database_name=N'master', 
		@flags=0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load capacity data', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Param (
    [parameter()]
    [string]$WarehouseServer = ''servername'',

    [parameter()]
    [string]$WarehouseDatabase = ''_dbaid_warehouse'',

    [parameter()]
    [System.String]$InputXmlRootPath = ''PathToXmlFilesToLoad''

)
$XMLPattern = ''*get_capacity_db*.xml''
$XMLFullFilePath = Join-Path $InputXmlRootPath $XMLPattern

$XMLFilelist = Get-ChildItem $XMLFullFilePath

foreach ($XMLFile in $XMLFileList) {
    $SqlQuery = ''DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '''''' + $XMLFile + '''''', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_capacity_db] ([instance_guid], [datetimeoffset], [database_name], [volume_mount_point], [data_type], [size_used_mb], [size_reserved_mb], [volume_available_mb])
  SELECT *
  FROM OPENXML(@hdoc, ''''//DocumentElement/get_capacity_db'''')
  WITH (
    [instance_guid] uniqueidentifier ''''instance_guid'''',
    [datetimeoffset] datetime2 ''''datetimeoffset'''',
    [database_name] sysname ''''database_name'''',
    [volume_mount_point] nvarchar(512) ''''volume_mount_point'''',
    [data_type] varchar(4) ''''data_type'''',
    [size_used_mb] numeric(20,2) ''''size_used_mb'''',
    [size_reserved_mb] numeric(20,2) ''''size_reserved_mb'''',
    [volume_available_mb] numeric(20,2) ''''volume_available_mb''''
  );

EXEC sp_xml_removedocument @hdoc;
GO''

    Invoke-Sqlcmd -ServerInstance $WarehouseServer -Database $WarehouseDatabase -Query $SqlQuery
}', 
		@database_name=N'master', 
		@flags=0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load agent job history', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Param (
    [parameter()]
    [string]$WarehouseServer = ''servername'',

    [parameter()]
    [string]$WarehouseDatabase = ''_dbaid_warehouse'',

    [parameter()]
    [System.String]$InputXmlRootPath = ''PathToXmlFilesToLoad''

)
$XMLPattern = ''*get_agentjob_history*.xml''
$XMLFullFilePath = Join-Path $InputXmlRootPath $XMLPattern

$XMLFilelist = Get-ChildItem $XMLFullFilePath

foreach ($XMLFile in $XMLFileList) {
    $SqlQuery = ''DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '''''' + $XMLFile + '''''', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_agentjob_history] ([instance_guid], [run_datetime], [job_name], [step_id], [step_name], [error_message], [run_status], [run_duration_sec])
  SELECT *
  FROM OPENXML(@hdoc, ''''//DocumentElement/get_agentjob_history'''')
  WITH (
    [instance_guid] uniqueidentifier ''''instance_guid'''',
    [run_datetime] datetime2 ''''run_datetime'''',
    [job_name] sysname ''''job_name'''',
    [step_id] int ''''step_id'''',
    [step_name] sysname ''''step_name'''',
    [error_message] nvarchar(2048) ''''error_message'''',
    [run_status] varchar(17) ''''run_status'''',
    [run_duration_sec] int ''''run_duration_sec''''
  );

EXEC sp_xml_removedocument @hdoc;
GO''

    Invoke-Sqlcmd -ServerInstance $WarehouseServer -Database $WarehouseDatabase -Query $SqlQuery
}', 
		@database_name=N'master', 
		@flags=0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load backup history', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Param (
    [parameter()]
    [string]$WarehouseServer = ''servername'',

    [parameter()]
    [string]$WarehouseDatabase = ''_dbaid_warehouse'',

    [parameter()]
    [System.String]$InputXmlRootPath = ''PathToXmlFilesToLoad''

)
$XMLPattern = ''*get_backup_history*.xml''
$XMLFullFilePath = Join-Path $InputXmlRootPath $XMLPattern

$XMLFilelist = Get-ChildItem $XMLFullFilePath

foreach ($XMLFile in $XMLFileList) {
    $SqlQuery = ''DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '''''' + $XMLFile + '''''', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_backup_history] ([instance_guid], [database_name], [backup_type], [backup_start_date], [backup_finish_date], [is_copy_only], [software_name], [user_name], [physical_device_name], [backup_size_mb], [compressed_backup_size_mb], [compression_ratio], [backup_check_full_hour], [backup_check_diff_hour], [backup_check_tran_hour])
  SELECT *
  FROM OPENXML(@hdoc, ''''//DocumentElement/get_backup_history'''')
  WITH (
    [instance_guid] uniqueidentifier ''''instance_guid'''',
    [database_name] sysname ''''database_name'''',
    [backup_type] char(1) ''''backup_type'''',
    [backup_start_date] datetime2 ''''backup_start_date'''',
    [backup_finish_date] datetime2 ''''backup_finish_date'''',
    [is_copy_only] bit ''''is_copy_only'''',
    [software_name] sysname ''''software_name'''',
    [user_name] sysname ''''user_name'''',
    [physical_device_name] nvarchar(260) ''''physical_device_name'''',
    [backup_size_mb] numeric(20,2) ''''backup_size_mb'''',
    [compressed_backup_size_mb] numeric(20,2) ''''compressed_backup_size_mb'''',
    [compression_ratio] numeric (20,2) ''''compression_ratio'''',
    [backup_check_full_hour] int ''''backup_check_full_hour'''',
    [backup_check_diff_hour] int ''''backup_check_diff_hour'''',
    [backup_check_tran_hour] int ''''backup_check_tran_hour''''
  );

EXEC sp_xml_removedocument @hdoc;
GO''

    Invoke-Sqlcmd -ServerInstance $WarehouseServer -Database $WarehouseDatabase -Query $SqlQuery
}', 
		@database_name=N'master', 
		@flags=0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Load errorlog history', 
		@step_id=6, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'Param (
    [parameter()]
    [string]$WarehouseServer = ''servername'',

    [parameter()]
    [string]$WarehouseDatabase = ''_dbaid_warehouse'',

    [parameter()]
    [System.String]$InputXmlRootPath = ''PathToXmlFilesToLoad''

)
$XMLPattern = ''*get_errorlog_history*.xml''
$XMLFullFilePath = Join-Path $InputXmlRootPath $XMLPattern

$XMLFilelist = Get-ChildItem $XMLFullFilePath

foreach ($XMLFile in $XMLFileList) {
    $SqlQuery = ''DECLARE @Doc xml,
        @hdoc int;

SET @Doc = (SELECT * FROM OPENROWSET(BULK '''''' + $XMLFile + '''''', SINGLE_BLOB) AS x);

EXEC sp_xml_prepareDocument @hdoc OUTPUT, @Doc;

INSERT INTO [dbo].[warehouse_errorlog] ([instance_guid], [log_date], [source], [message_header], [message])
  SELECT *
  FROM OPENXML(@hdoc, ''''//DocumentElement/get_errorlog_history'''')
  WITH (
    [instance_guid] uniqueidentifier ''''instance_guid'''',
    [log_date] datetime2 ''''log_date'''',
    [source] nvarchar(100) ''''source'''',
    [message_header] nvarchar(max) ''''message_header'''',
    [message] nvarchar(max) ''''message''''
  );

EXEC sp_xml_removedocument @hdoc;
GO''

    Invoke-Sqlcmd -ServerInstance $WarehouseServer -Database $WarehouseDatabase -Query $SqlQuery
}', 
		@database_name=N'master', 
		@flags=0;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'_dbaid_warehouse_load', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20201104, 
		@active_end_date=99991231, 
		@active_start_time=70000, 
		@active_end_time=235959;
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback;
COMMIT TRANSACTION
GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION;

EndSave:
GO


