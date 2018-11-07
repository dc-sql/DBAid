CREATE PROCEDURE [datamart].[process_stage_data]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

	/* process_stage_errorlog_history */
	BEGIN TRANSACTION [process_stage_errorlog_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[instance_guid] = [stage].[instance_guid]
			FROM [datamart].[stage_errorlog_history] [stage]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [stage].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([stage].[log_date] AS DATE)
				,[year] = DATEPART(YEAR, [stage].[log_date])
				,[month] = DATEPART(MONTH, [stage].[log_date])
				,[day] = DATEPART(DAY, [stage].[log_date])
				,[day_name] = DATENAME(DW, [stage].[log_date])
				,[quarter] = DATEPART(QUARTER, [stage].[log_date])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [stage].[log_date]) + 1, 0))
			FROM [datamart].[stage_errorlog_history] [stage]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([stage].[log_date] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([stage].[log_date] AS TIME)
				,[hour] = DATEPART(HOUR, [stage].[log_date])
				,[minute] = DATENAME(MINUTE, [stage].[log_date])
				,[second] = DATEPART(SECOND, [stage].[log_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [stage].[log_date])
			FROM [datamart].[stage_errorlog_history] [stage]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([stage].[log_date] AS TIME) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_errorlog_history] ([instance_id], [date_id], [time_id], [count], [source], [message_header], [message])
			SELECT [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[count] = COUNT(*)
				,[f].[source]
				,[f].[message_header]
				,[f].[message]
			FROM [datamart].[stage_errorlog_history] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_date] [dd]
					ON CAST([f].[log_date] AS DATE) = [dd].[date]
				INNER JOIN [datamart].[dim_time] [dt]
					ON CAST([f].[log_date] AS TIME) = [dt].[time]
			GROUP BY [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[f].[source]
				,[f].[message_header]
				,[f].[message];

		TRUNCATE TABLE [datamart].[stage_errorlog_history];
		COMMIT TRANSACTION [process_stage_errorlog_history];
	END TRY
	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[stage_errorlog_history].'
		ROLLBACK TRANSACTION [process_stage_errorlog_history];
	END CATCH

END
