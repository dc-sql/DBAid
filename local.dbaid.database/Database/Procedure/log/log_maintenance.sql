/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[maintenance]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@mark_runtime BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @report_datetime DATETIME;
		
	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=[last_execution_datetime] FROM [dbo].[procedure] WHERE [procedure_id] = @@PROCID;
		IF @start_datetime IS NULL SET @start_datetime=DATEADD(DAY,-1,GETDATE());
	END

	SET @report_datetime = GETDATE();

	IF (@end_datetime IS NULL)
		SET @end_datetime = @report_datetime;

	BEGIN TRANSACTION
		SELECT [instance].[guid] AS [instance_guid]
			,[D].[date1] AS [start_time]
			,[D].[date2] AS [end_time]
			,[p].[name] AS [plan_name]
			,[sj].[name] AS [job_name]
			,[description].[string] AS [description]
			,[ld].[succeeded]
			,[ld].[error_number]
			,[error].[string] AS [error_message]
		FROM [msdb].[dbo].[sysmaintplan_plans] [p]
			INNER JOIN msdb.dbo.sysmaintplan_subplans [sp]
				ON [p].[id] = [sp].[plan_id]
			INNER JOIN msdb.dbo.sysmaintplan_log [l] 
				ON [sp].[subplan_id] = [l].[subplan_id] AND [p].[id] = [l].[plan_id]
			LEFT JOIN msdb.dbo.sysmaintplan_logdetail [ld]
				ON [l].[task_detail_id] = [ld].[task_detail_id]
			LEFT JOIN msdb.dbo.sysjobs [sj]
				ON [sp].[job_id] = [sj].[job_id]
			CROSS APPLY [dbo].[instanceguid]() [instance]
			CROSS APPLY [dbo].[cleanstring]([ld].[line1] + CASE WHEN LEN([ld].[line2]) > 0 THEN ' | ' ELSE '' END 
											+ [ld].[line2] + CASE WHEN LEN([ld].[line3]) > 0 THEN ' | ' ELSE '' END 
											+ [ld].[line3] + CASE WHEN LEN([ld].[line4]) > 0 THEN ' | ' ELSE '' END 
											+ [ld].[line4] + CASE WHEN LEN([ld].[line5]) > 0 THEN ' | ' ELSE '' END 
											+ [ld].[line5]) [description]
			CROSS APPLY [dbo].[cleanstring]([ld].[error_message]) [error]
			CROSS APPLY [dbo].[string_date_with_offset]([ld].[start_time], [ld].[end_time]) [D]
		WHERE [ld].[start_time] BETWEEN @start_datetime AND @end_datetime
		ORDER BY [ld].[start_time], [ld].[end_time];

		IF ((SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME() OR @mark_runtime = 1)
			UPDATE [dbo].[procedure] SET [last_execution_datetime] = @end_datetime WHERE [procedure_id] = @@PROCID;
		
		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION;
			RETURN 1;
		END
	COMMIT TRANSACTION
END;