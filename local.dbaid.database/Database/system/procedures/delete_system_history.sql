/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [system].[delete_system_history]
	@job_olderthan_day INT = 92,
	@backup_olderthan_day INT = 92,
	@dbmail_olderthan_day INT = 92,
	@maintplan_olderthan_day INT = 92,
	@ola_cmdlog_olderthan_day INT = 92
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @olderthan_date DATETIME, @return_code INT, @error_count INT, @agent_id UNIQUEIDENTIFIER, @agent_type INT;
	
	SET @error_count = 0;
	IF @job_olderthan_day > 0 SET @job_olderthan_day = @job_olderthan_day * -1;
	IF @backup_olderthan_day > 0 SET @backup_olderthan_day = @backup_olderthan_day * -1;
	IF @dbmail_olderthan_day > 0 SET @dbmail_olderthan_day = @dbmail_olderthan_day * -1;
	IF @maintplan_olderthan_day > 0 SET @maintplan_olderthan_day = @maintplan_olderthan_day * -1;
	IF @ola_cmdlog_olderthan_day > 0 SET @ola_cmdlog_olderthan_day = @ola_cmdlog_olderthan_day * -1;
	
	/* Clean-up ola commandlog */
	DELETE FROM [dbo].[CommandLog] WHERE [EndTime] < DATEADD(DAY, @ola_cmdlog_olderthan_day, GETDATE());

	/* Clean-up logshipping history */
	DECLARE curse CURSOR FAST_FORWARD FOR
	SELECT [agent_id], [agent_type] 
	FROM msdb.dbo.log_shipping_monitor_history_detail WITH(NOLOCK)
	GROUP BY [agent_id], [agent_type]

	OPEN curse;
	FETCH NEXT FROM curse INTO @agent_id, @agent_type;

	WHILE(@@FETCH_STATUS=0)
	BEGIN
		EXEC @return_code = [master].[sys].[sp_cleanup_log_shipping_history] @agent_id, @agent_type;
		IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_maintplan_delete_log] - failed to purge data.'; END
		FETCH NEXT FROM curse INTO @agent_id, @agent_type;
	END

	CLOSE curse;
	DEALLOCATE curse;

	/* Clean-up job history */
	SET @olderthan_date = DATEADD(DAY, @job_olderthan_day, GETDATE());
	EXECUTE @return_code = [msdb].[dbo].[sp_purge_jobhistory] @oldest_date = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_purge_jobhistory] - failed to purge data.'; END

	/* Clean-up backup history */
	SET @olderthan_date = DATEADD(DAY, @backup_olderthan_day, GETDATE());
	EXECUTE @return_code = [msdb].[dbo].[sp_delete_backuphistory] @oldest_date = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_delete_backuphistory] - failed to purge data.'; END

	/* Clean-up database mail history */
	SET @olderthan_date = DATEADD(DAY, @dbmail_olderthan_day, GETDATE());
	EXEC @return_code = [msdb].[dbo].[sysmail_delete_mailitems_sp] @sent_before = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sysmail_delete_mailitems_sp] - failed to purge data.'; END

	EXEC @return_code = [msdb].[dbo].[sysmail_delete_log_sp] @logged_before = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sysmail_delete_log_sp] - failed to purge data.'; END

	/* Clean-up maint plan history */
	SET @olderthan_date = DATEADD(DAY, @maintplan_olderthan_day, GETDATE());
	EXEC @return_code = [msdb].[dbo].[sp_maintplan_delete_log] @plan_id = NULL, @subplan_id = NULL, @oldest_time = @olderthan_date;
	IF (@return_code <> 0) BEGIN SET @error_count = @error_count + 1; PRINT '[sp_maintplan_delete_log] - failed to purge data.'; END

	IF (@error_count <> 0) RETURN 1;
	ELSE RETURN 0;
END
