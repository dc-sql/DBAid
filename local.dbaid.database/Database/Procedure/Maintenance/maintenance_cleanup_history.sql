/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [maintenance].[cleanup_history]
	@job_olderthan_day INT = 92,
	@backup_olderthan_day INT = 92,
	@cmdlog_olderthan_day INT = 92,
	@dbmail_olderthan_day INT = 92,
	@maintplan_olderthan_day INT = 92
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @olderthan_date DATETIME, @return_code INT, @error_count INT;
	SET @error_count = 0;

	IF @job_olderthan_day > 0 SET @job_olderthan_day = @job_olderthan_day * -1;
	IF @backup_olderthan_day > 0 SET @backup_olderthan_day = @backup_olderthan_day * -1;
	IF @cmdlog_olderthan_day > 0 SET @cmdlog_olderthan_day = @cmdlog_olderthan_day * -1;

	SET @olderthan_date = DATEADD(DAY, @job_olderthan_day, GETDATE());
	EXECUTE @return_code = [msdb].[dbo].[sp_purge_jobhistory] @oldest_date = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_purge_jobhistory] - failed to purge data.'; END

	SET @olderthan_date = DATEADD(DAY, @backup_olderthan_day, GETDATE());
	EXECUTE @return_code = [msdb].[dbo].[sp_delete_backuphistory] @oldest_date = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_delete_backuphistory] - failed to purge data.'; END

	SET @olderthan_date = DATEADD(DAY, @dbmail_olderthan_day, GETDATE());
	EXEC @return_code = [msdb].[dbo].[sysmail_delete_mailitems_sp] @sent_before = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sysmail_delete_mailitems_sp] - failed to purge data.'; END

	EXEC @return_code = [msdb].[dbo].[sysmail_delete_log_sp] @logged_before = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sysmail_delete_log_sp] - failed to purge data.'; END

	SET @olderthan_date = DATEADD(DAY, @maintplan_olderthan_day, GETDATE());
	EXEC @return_code = [msdb].[dbo].[sp_maintplan_delete_log] @plan_id = NULL, @subplan_id = NULL, @oldest_time = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_maintplan_delete_log] - failed to purge data.'; END

	DELETE FROM [dbo].[CommandLog] WHERE [StartTime] < DATEADD(DAY, @cmdlog_olderthan_day, GETDATE());
	IF (@@ERROR <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[CommandLog] - failed to purge data.'; END

	REVERT;

	IF (@error_count <> 0) RETURN 1;
	ELSE RETURN 0;
END