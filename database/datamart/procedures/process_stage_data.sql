CREATE PROCEDURE [datamart].[process_stage_data]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
	DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;

	/* process stage_errorlog_history */
	BEGIN TRANSACTION [process_stage_errorlog_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[stage].[instance_guid]
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
				[time] = CAST([stage].[log_date] AS TIME(0))
				,[hour] = DATEPART(HOUR, [stage].[log_date])
				,[minute] = DATENAME(MINUTE, [stage].[log_date])
				,[second] = DATEPART(SECOND, [stage].[log_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [stage].[log_date])
			FROM [datamart].[stage_errorlog_history] [stage]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([stage].[log_date] AS TIME(0)) = [dim].[time]
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
					ON CAST([f].[log_date] AS TIME(0)) = [dt].[time]
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
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[stage_errorlog_history].'
		ROLLBACK TRANSACTION [process_stage_errorlog_history];
	END CATCH

	/* process stage_agentjob_history */
	BEGIN TRANSACTION [process_stage_agentjob_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[stage].[instance_guid]
			FROM [datamart].[stage_agentjob_history] [stage]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [stage].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([stage].[run_datetime] AS DATE)
				,[year] = DATEPART(YEAR, [stage].[run_datetime])
				,[month] = DATEPART(MONTH, [stage].[run_datetime])
				,[day] = DATEPART(DAY, [stage].[run_datetime])
				,[day_name] = DATENAME(DW, [stage].[run_datetime])
				,[quarter] = DATEPART(QUARTER, [stage].[run_datetime])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [stage].[run_datetime]) + 1, 0))
			FROM [datamart].[stage_agentjob_history] [stage]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([stage].[run_datetime] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([stage].[run_datetime] AS TIME(0))
				,[hour] = DATEPART(HOUR, [stage].[run_datetime])
				,[minute] = DATENAME(MINUTE, [stage].[run_datetime])
				,[second] = DATEPART(SECOND, [stage].[run_datetime])
				,[timezone_offset] = DATEPART(TZOFFSET, [stage].[run_datetime])
			FROM [datamart].[stage_agentjob_history] [stage]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([stage].[run_datetime] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_agentjob_history] ([instance_id], [date_id], [time_id], [count], [job_name], [step_id], [step_name], [error_message], [run_status], [run_duration_sec])
			SELECT [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[count] = COUNT(*)
				,[f].[job_name]
				,[f].[step_id]
				,[f].[step_name]
				,[f].[error_message]
				,[f].[run_status]
				,[f].[run_duration_sec]
			FROM [datamart].[stage_agentjob_history] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_date] [dd]
					ON CAST([f].[run_datetime] AS DATE) = [dd].[date]
				INNER JOIN [datamart].[dim_time] [dt]
					ON CAST([f].[run_datetime] AS TIME(0)) = [dt].[time]
			GROUP BY [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[f].[job_name]
				,[f].[step_id]
				,[f].[step_name]
				,[f].[error_message]
				,[f].[run_status]
				,[f].[run_duration_sec];

		TRUNCATE TABLE [datamart].[stage_agentjob_history];
		COMMIT TRANSACTION [process_stage_agentjob_history];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[stage_agentjob_history].'
		ROLLBACK TRANSACTION [process_stage_agentjob_history];
	END CATCH

	/* process stage_backup_history */
	BEGIN TRANSACTION [process_stage_backup_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[stage].[instance_guid]
			FROM [datamart].[stage_backup_history] [stage]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [stage].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate database dimension */
		INSERT INTO [datamart].[dim_database] ([instance_id],[name])
			SELECT DISTINCT 
				[di].[instance_id]
				,[stage].[database_name]
			FROM [datamart].[stage_backup_history] [stage]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [stage].[instance_guid] = [di].[instance_guid]
				LEFT JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [stage].[database_name] = [db].[name]
			WHERE [db].[name] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([stage].[backup_start_date] AS DATE)
				,[year] = DATEPART(YEAR, [stage].[backup_start_date])
				,[month] = DATEPART(MONTH, [stage].[backup_start_date])
				,[day] = DATEPART(DAY, [stage].[backup_start_date])
				,[day_name] = DATENAME(DW, [stage].[backup_start_date])
				,[quarter] = DATEPART(QUARTER, [stage].[backup_start_date])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [stage].[backup_start_date]) + 1, 0))
			FROM [datamart].[stage_backup_history] [stage]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([stage].[backup_start_date] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL
			UNION SELECT DISTINCT 
				[date] = CAST([stage].[backup_finish_date] AS DATE)
				,[year] = DATEPART(YEAR, [stage].[backup_finish_date])
				,[month] = DATEPART(MONTH, [stage].[backup_finish_date])
				,[day] = DATEPART(DAY, [stage].[backup_finish_date])
				,[day_name] = DATENAME(DW, [stage].[backup_finish_date])
				,[quarter] = DATEPART(QUARTER, [stage].[backup_finish_date])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [stage].[backup_finish_date]) + 1, 0))
			FROM [datamart].[stage_backup_history] [stage]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([stage].[backup_finish_date] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([stage].[backup_start_date] AS TIME(0))
				,[hour] = DATEPART(HOUR, [stage].[backup_start_date])
				,[minute] = DATENAME(MINUTE, [stage].[backup_start_date])
				,[second] = DATEPART(SECOND, [stage].[backup_start_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [stage].[backup_start_date])
			FROM [datamart].[stage_backup_history] [stage]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([stage].[backup_start_date] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL
			UNION SELECT DISTINCT
				[time] = CAST([stage].[backup_finish_date] AS TIME(0))
				,[hour] = DATEPART(HOUR, [stage].[backup_finish_date])
				,[minute] = DATENAME(MINUTE, [stage].[backup_finish_date])
				,[second] = DATEPART(SECOND, [stage].[backup_finish_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [stage].[backup_finish_date])
			FROM [datamart].[stage_backup_history] [stage]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([stage].[backup_finish_date] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_backup_history] ([instance_id],[database_id],[start_date_id],[start_time_id],[finish_date_id],[finish_time_id],[type],[is_copy_only]
													,[software_name],[user_name],[physical_device_name],[size_mb],[compressed_size_mb],[compression_ratio],[encryptor_type]
													,[encryptor_thumbprint],[is_password_protected],[backup_check_full_hour],[backup_check_diff_hour],[backup_check_tran_hour])
			SELECT [di].[instance_id]
				,[db].[database_id]
				,[start_date_id] = [dd1].[date_id]
				,[start_time_id] = [dt1].[time_id]
				,[finish_date_id] = [dd2].[date_id]
				,[finish_time_id] = [dt2].[time_id]
				,[backup_type]
				,[is_copy_only]
				,[software_name]
				,[user_name]
				,[physical_device_name]
				,[backup_size_mb]
				,[compressed_backup_size_mb]
				,[compression_ratio]
				,[encryptor_type]
				,[encryptor_thumbprint]
				,[is_password_protected]
				,[backup_check_full_hour]
				,[backup_check_diff_hour]
				,[backup_check_tran_hour]
			FROM [datamart].[stage_backup_history] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [f].[database_name] = [db].[name]
				INNER JOIN [datamart].[dim_date] [dd1]
					ON CAST([f].[backup_start_date] AS DATE) = [dd1].[date]
				INNER JOIN [datamart].[dim_time] [dt1]
					ON CAST([f].[backup_start_date] AS TIME(0)) = [dt1].[time]
				INNER JOIN [datamart].[dim_date] [dd2]
					ON CAST([f].[backup_finish_date] AS DATE) = [dd2].[date]
				INNER JOIN [datamart].[dim_time] [dt2]
					ON CAST([f].[backup_finish_date] AS TIME(0)) = [dt2].[time]

		TRUNCATE TABLE [datamart].[stage_backup_history];
		COMMIT TRANSACTION [process_stage_backup_history];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[stage_backup_history].'
		ROLLBACK TRANSACTION [process_stage_backup_history];
	END CATCH

	/* process stage_capacity_db */
	BEGIN TRANSACTION [process_stage_capacity_db];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[stage].[instance_guid]
			FROM [datamart].[stage_capacity_db] [stage]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [stage].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate database dimension */
		INSERT INTO [datamart].[dim_database] ([instance_id],[name])
			SELECT DISTINCT 
				[di].[instance_id]
				,[stage].[database_name]
			FROM [datamart].[stage_capacity_db] [stage]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [stage].[instance_guid] = [di].[instance_guid]
				LEFT JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [stage].[database_name] = [db].[name]
			WHERE [db].[name] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([stage].[datetimeoffset] AS DATE)
				,[year] = DATEPART(YEAR, [stage].[datetimeoffset])
				,[month] = DATEPART(MONTH, [stage].[datetimeoffset])
				,[day] = DATEPART(DAY, [stage].[datetimeoffset])
				,[day_name] = DATENAME(DW, [stage].[datetimeoffset])
				,[quarter] = DATEPART(QUARTER, [stage].[datetimeoffset])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [stage].[datetimeoffset]) + 1, 0))
			FROM [datamart].[stage_capacity_db] [stage]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([stage].[datetimeoffset] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([stage].[datetimeoffset] AS TIME(0))
				,[hour] = DATEPART(HOUR, [stage].[datetimeoffset])
				,[minute] = DATENAME(MINUTE, [stage].[datetimeoffset])
				,[second] = DATEPART(SECOND, [stage].[datetimeoffset])
				,[timezone_offset] = DATEPART(TZOFFSET, [stage].[datetimeoffset])
			FROM [datamart].[stage_capacity_db] [stage]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([stage].[datetimeoffset] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_capacity_db] ([instance_id],[database_id],[date_id],[time_id],[volume_mount_point],[data_type],[size_used_mb],[size_reserved_mb],[volume_available_mb])
			SELECT [di].[instance_id]
				,[db].[database_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[volume_mount_point]
				,[data_type]
				,[size_used_mb]
				,[size_reserved_mb]
				,[volume_available_mb]
			FROM [datamart].[stage_capacity_db] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [f].[database_name] = [db].[name]
				INNER JOIN [datamart].[dim_date] [dd]
					ON CAST([f].[datetimeoffset] AS DATE) = [dd].[date]
				INNER JOIN [datamart].[dim_time] [dt]
					ON CAST([f].[datetimeoffset] AS TIME(0)) = [dt].[time];

		TRUNCATE TABLE [datamart].[stage_capacity_db];
		COMMIT TRANSACTION [process_stage_capacity_db];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[stage_agentjob_history].'
		ROLLBACK TRANSACTION [process_stage_capacity_db];
	END CATCH
END
