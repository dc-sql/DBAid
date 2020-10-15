CREATE VIEW [dbo].[active_backup_restore]
AS
	SELECT [start_time]
		,[command]
		,[percent_complete]
		,[estimate_completion_min] = [estimated_completion_time]/1000.00/60
		,[estimated_completion_time] = DATEADD(MILLISECOND,[estimated_completion_time],GETDATE())
		,[session_id]
		,[status]
		,[blocking_session_id]
		,[wait_type]
		,[last_wait_type]
		,[wait_time]
	FROM sys.dm_exec_requests 
	WHERE [command] LIKE 'BACKUP %' 
		OR [command] LIKE 'RESTORE %'
