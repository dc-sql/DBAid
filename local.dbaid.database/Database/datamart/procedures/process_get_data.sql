/*



*/

CREATE PROCEDURE [datamart].[process_get_data]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
	DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;

/* process get_instance_ci */
	BEGIN TRANSACTION [process_get_instance_ci];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[get].[instance_guid]
			FROM [datamart].[get_instance_ci] [get]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [get].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		MERGE INTO [datamart].[dim_instance] [dim]
		USING [datamart].[get_instance_ci] [get]
			ON [dim].[instance_guid] = [get].[instance_guid]
				AND [get].[property] = 'ServerName'
		WHEN MATCHED THEN
			UPDATE SET [name] = CAST([get].[value] AS NVARCHAR(128));

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([get].[datetimeoffset] AS DATE)
				,[year] = DATEPART(YEAR, [get].[datetimeoffset])
				,[month] = DATEPART(MONTH, [get].[datetimeoffset])
				,[day] = DATEPART(DAY, [get].[datetimeoffset])
				,[day_name] = DATENAME(DW, [get].[datetimeoffset])
				,[quarter] = DATEPART(QUARTER, [get].[datetimeoffset])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[datetimeoffset]) + 1, 0))
			FROM [datamart].[get_instance_ci] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[datetimeoffset] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([get].[datetimeoffset] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[datetimeoffset])
				,[minute] = DATENAME(MINUTE, [get].[datetimeoffset])
				,[second] = DATEPART(SECOND, [get].[datetimeoffset])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[datetimeoffset])
			FROM [datamart].[get_instance_ci] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[datetimeoffset] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_instance_ci] ([instance_id], [date_id], [time_id], [property], [value])
			SELECT [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[f].[property]
				,[f].[value]
			FROM [datamart].[get_instance_ci] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_date] [dd]
					ON CAST([f].[datetimeoffset] AS DATE) = [dd].[date]
				INNER JOIN [datamart].[dim_time] [dt]
					ON CAST([f].[datetimeoffset] AS TIME(0)) = [dt].[time]
			WHERE [f].[value] IS NOT NULL
			GROUP BY [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[f].[property]
				,[f].[value];

		TRUNCATE TABLE [datamart].[get_instance_ci];
		COMMIT TRANSACTION [process_get_instance_ci];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[get_instance_ci].'
		ROLLBACK TRANSACTION [process_get_instance_ci];
	END CATCH

/* process get_database_ci */
	BEGIN TRANSACTION [process_get_database_ci];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[get].[instance_guid]
			FROM [datamart].[get_database_ci] [get]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [get].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate database dimension */
		INSERT INTO [datamart].[dim_database] ([instance_id],[name])
			SELECT DISTINCT 
				[di].[instance_id]
				,[get].[name]
			FROM [datamart].[get_database_ci] [get]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [get].[instance_guid] = [di].[instance_guid]
				LEFT JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [get].[name] = [db].[name]
			WHERE [db].[name] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([get].[datetimeoffset] AS DATE)
				,[year] = DATEPART(YEAR, [get].[datetimeoffset])
				,[month] = DATEPART(MONTH, [get].[datetimeoffset])
				,[day] = DATEPART(DAY, [get].[datetimeoffset])
				,[day_name] = DATENAME(DW, [get].[datetimeoffset])
				,[quarter] = DATEPART(QUARTER, [get].[datetimeoffset])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[datetimeoffset]) + 1, 0))
			FROM [datamart].[get_database_ci] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[datetimeoffset] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([get].[datetimeoffset] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[datetimeoffset])
				,[minute] = DATENAME(MINUTE, [get].[datetimeoffset])
				,[second] = DATEPART(SECOND, [get].[datetimeoffset])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[datetimeoffset])
			FROM [datamart].[get_database_ci] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[datetimeoffset] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_database_ci] ([instance_id], [database_id], [date_id], [time_id], [property], [value])
			SELECT [di].[instance_id]
				,[db].[database_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[f].[property]
				,[f].[value]
			FROM [datamart].[get_database_ci] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [f].[name] = [db].[name]
				INNER JOIN [datamart].[dim_date] [dd]
					ON CAST([f].[datetimeoffset] AS DATE) = [dd].[date]
				INNER JOIN [datamart].[dim_time] [dt]
					ON CAST([f].[datetimeoffset] AS TIME(0)) = [dt].[time]
			WHERE [f].[value] IS NOT NULL
			GROUP BY [di].[instance_id]
				,[db].[database_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[f].[property]
				,[f].[value];

		TRUNCATE TABLE [datamart].[get_database_ci];
		COMMIT TRANSACTION [process_get_database_ci];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[get_database_ci].'
		ROLLBACK TRANSACTION [process_get_database_ci];
	END CATCH

/* process get_errorlog_history */
	BEGIN TRANSACTION [process_get_errorlog_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[get].[instance_guid]
			FROM [datamart].[get_errorlog_history] [get]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [get].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([get].[log_date] AS DATE)
				,[year] = DATEPART(YEAR, [get].[log_date])
				,[month] = DATEPART(MONTH, [get].[log_date])
				,[day] = DATEPART(DAY, [get].[log_date])
				,[day_name] = DATENAME(DW, [get].[log_date])
				,[quarter] = DATEPART(QUARTER, [get].[log_date])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[log_date]) + 1, 0))
			FROM [datamart].[get_errorlog_history] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[log_date] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([get].[log_date] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[log_date])
				,[minute] = DATENAME(MINUTE, [get].[log_date])
				,[second] = DATEPART(SECOND, [get].[log_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[log_date])
			FROM [datamart].[get_errorlog_history] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[log_date] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL;

		INSERT INTO [datamart].[fact_errorlog_history] ([instance_id], [date_id], [time_id], [count], [source], [message_header], [message])
			SELECT [di].[instance_id]
				,[dd].[date_id]
				,[dt].[time_id]
				,[count] = COUNT(*)
				,[f].[source]
				,[f].[message_header]
				,[f].[message]
			FROM [datamart].[get_errorlog_history] [f]
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

		TRUNCATE TABLE [datamart].[get_errorlog_history];
		COMMIT TRANSACTION [process_get_errorlog_history];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[get_errorlog_history].'
		ROLLBACK TRANSACTION [process_get_errorlog_history];
	END CATCH

/* process get_agentjob_history */
	BEGIN TRANSACTION [process_get_agentjob_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[get].[instance_guid]
			FROM [datamart].[get_agentjob_history] [get]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [get].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([get].[run_datetime] AS DATE)
				,[year] = DATEPART(YEAR, [get].[run_datetime])
				,[month] = DATEPART(MONTH, [get].[run_datetime])
				,[day] = DATEPART(DAY, [get].[run_datetime])
				,[day_name] = DATENAME(DW, [get].[run_datetime])
				,[quarter] = DATEPART(QUARTER, [get].[run_datetime])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[run_datetime]) + 1, 0))
			FROM [datamart].[get_agentjob_history] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[run_datetime] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([get].[run_datetime] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[run_datetime])
				,[minute] = DATENAME(MINUTE, [get].[run_datetime])
				,[second] = DATEPART(SECOND, [get].[run_datetime])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[run_datetime])
			FROM [datamart].[get_agentjob_history] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[run_datetime] AS TIME(0)) = [dim].[time]
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
			FROM [datamart].[get_agentjob_history] [f]
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

		TRUNCATE TABLE [datamart].[get_agentjob_history];
		COMMIT TRANSACTION [process_get_agentjob_history];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[get_agentjob_history].'
		ROLLBACK TRANSACTION [process_get_agentjob_history];
	END CATCH

/* process get_backup_history */
	BEGIN TRANSACTION [process_get_backup_history];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[get].[instance_guid]
			FROM [datamart].[get_backup_history] [get]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [get].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate database dimension */
		INSERT INTO [datamart].[dim_database] ([instance_id],[name])
			SELECT DISTINCT 
				[di].[instance_id]
				,[get].[database_name]
			FROM [datamart].[get_backup_history] [get]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [get].[instance_guid] = [di].[instance_guid]
				LEFT JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [get].[database_name] = [db].[name]
			WHERE [db].[name] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([get].[backup_start_date] AS DATE)
				,[year] = DATEPART(YEAR, [get].[backup_start_date])
				,[month] = DATEPART(MONTH, [get].[backup_start_date])
				,[day] = DATEPART(DAY, [get].[backup_start_date])
				,[day_name] = DATENAME(DW, [get].[backup_start_date])
				,[quarter] = DATEPART(QUARTER, [get].[backup_start_date])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[backup_start_date]) + 1, 0))
			FROM [datamart].[get_backup_history] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[backup_start_date] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL
			UNION SELECT DISTINCT 
				[date] = CAST([get].[backup_finish_date] AS DATE)
				,[year] = DATEPART(YEAR, [get].[backup_finish_date])
				,[month] = DATEPART(MONTH, [get].[backup_finish_date])
				,[day] = DATEPART(DAY, [get].[backup_finish_date])
				,[day_name] = DATENAME(DW, [get].[backup_finish_date])
				,[quarter] = DATEPART(QUARTER, [get].[backup_finish_date])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[backup_finish_date]) + 1, 0))
			FROM [datamart].[get_backup_history] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[backup_finish_date] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([get].[backup_start_date] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[backup_start_date])
				,[minute] = DATENAME(MINUTE, [get].[backup_start_date])
				,[second] = DATEPART(SECOND, [get].[backup_start_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[backup_start_date])
			FROM [datamart].[get_backup_history] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[backup_start_date] AS TIME(0)) = [dim].[time]
			WHERE [dim].[time_id] IS NULL
			UNION SELECT DISTINCT
				[time] = CAST([get].[backup_finish_date] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[backup_finish_date])
				,[minute] = DATENAME(MINUTE, [get].[backup_finish_date])
				,[second] = DATEPART(SECOND, [get].[backup_finish_date])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[backup_finish_date])
			FROM [datamart].[get_backup_history] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[backup_finish_date] AS TIME(0)) = [dim].[time]
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
			FROM [datamart].[get_backup_history] [f]
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

		TRUNCATE TABLE [datamart].[get_backup_history];
		COMMIT TRANSACTION [process_get_backup_history];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[get_backup_history].'
		ROLLBACK TRANSACTION [process_get_backup_history];
	END CATCH

/* process get_capacity_db */
	BEGIN TRANSACTION [process_get_capacity_db];
	BEGIN TRY
		/* populate instance dimension */
		INSERT INTO [datamart].[dim_instance] ([instance_guid])
			SELECT DISTINCT 
				[get].[instance_guid]
			FROM [datamart].[get_capacity_db] [get]
				LEFT JOIN [datamart].[dim_instance] [dim]
					ON [get].[instance_guid] = [dim].[instance_guid]
			WHERE [dim].[instance_guid] IS NULL;

		/* populate database dimension */
		INSERT INTO [datamart].[dim_database] ([instance_id],[name])
			SELECT DISTINCT 
				[di].[instance_id]
				,[get].[database_name]
			FROM [datamart].[get_capacity_db] [get]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [get].[instance_guid] = [di].[instance_guid]
				LEFT JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [get].[database_name] = [db].[name]
			WHERE [db].[name] IS NULL;

		/* populate date dimension */
		INSERT INTO [datamart].[dim_date]
			SELECT DISTINCT 
				[date] = CAST([get].[datetimeoffset] AS DATE)
				,[year] = DATEPART(YEAR, [get].[datetimeoffset])
				,[month] = DATEPART(MONTH, [get].[datetimeoffset])
				,[day] = DATEPART(DAY, [get].[datetimeoffset])
				,[day_name] = DATENAME(DW, [get].[datetimeoffset])
				,[quarter] = DATEPART(QUARTER, [get].[datetimeoffset])
				,[end_of_month] = DATEADD (DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [get].[datetimeoffset]) + 1, 0))
			FROM [datamart].[get_capacity_db] [get]
				LEFT JOIN [datamart].[dim_date] [dim]
					ON CAST([get].[datetimeoffset] AS DATE) = [dim].[date]
			WHERE [dim].[date_id] IS NULL;
		
		/* populate time dimension */
		INSERT INTO [datamart].[dim_time] 
			SELECT DISTINCT
				[time] = CAST([get].[datetimeoffset] AS TIME(0))
				,[hour] = DATEPART(HOUR, [get].[datetimeoffset])
				,[minute] = DATENAME(MINUTE, [get].[datetimeoffset])
				,[second] = DATEPART(SECOND, [get].[datetimeoffset])
				,[timezone_offset] = DATEPART(TZOFFSET, [get].[datetimeoffset])
			FROM [datamart].[get_capacity_db] [get]
				LEFT JOIN [datamart].[dim_time] [dim]
					ON CAST([get].[datetimeoffset] AS TIME(0)) = [dim].[time]
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
			FROM [datamart].[get_capacity_db] [f]
				INNER JOIN [datamart].[dim_instance] [di]
					ON [f].[instance_guid] = [di].[instance_guid]
				INNER JOIN [datamart].[dim_database] [db]
					ON [di].[instance_id] = [db].[instance_id]
						AND [f].[database_name] = [db].[name]
				INNER JOIN [datamart].[dim_date] [dd]
					ON CAST([f].[datetimeoffset] AS DATE) = [dd].[date]
				INNER JOIN [datamart].[dim_time] [dt]
					ON CAST([f].[datetimeoffset] AS TIME(0)) = [dt].[time];

		TRUNCATE TABLE [datamart].[get_capacity_db];
		COMMIT TRANSACTION [process_get_capacity_db];
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();  
		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);

		PRINT 'Failed to process [datamart].[get_agentjob_history].'
		ROLLBACK TRANSACTION [process_get_capacity_db];
	END CATCH
END
