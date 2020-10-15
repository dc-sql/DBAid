/*
Returns backup history from msdb.

PARAMETERS
	INPUT
		@start_datetime DATETIME
		Earliest backup history row to return. Default NULL uses last execution datetime or -1 day. 
		
		@end_datetime DATETIME
		Latest backup history row to return. Default NULL returns latest. 

		@update_execution_timestamp BIT
		Updates table [collector].[last_execution]. Use this to create time windows for collection. Default 0 will not update.
*/

CREATE PROCEDURE [collector].[get_backup_history]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @compression BIT;
	DECLARE @cmd VARCHAR(MAX);

	DECLARE @output TABLE ([database_name] NVARCHAR(128),
							[backup_type] CHAR(1),
							[is_copy_only] BIT,
							[backup_start_date] DATETIME,
							[backup_finish_date] DATETIME,
							[software_name] NVARCHAR(128),
							[user_name] NVARCHAR(128),
							[physical_device_name] NVARCHAR(260),
							[backup_size_mb] NUMERIC(20,2),
							[compressed_backup_size_mb] NUMERIC(20,2),
							[compression_ratio] NUMERIC(5,2));

	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=ISNULL([last_execution], DATEADD(DAY,-1,GETDATE())) 
		FROM [collector].[last_execution] WHERE [object_name] = OBJECT_NAME(@@PROCID);
	END

	IF (@end_datetime IS NULL)
		SET @end_datetime = GETDATE();

	INSERT INTO @output 
		SELECT [database_name]=[D].[name]
			,[backup_type]=[B].[type]
			,[B].[is_copy_only]
			,[B].[backup_start_date]
			,[B].[backup_finish_date]
			,[MS].[software_name]
			,[B].[user_name]
			,[M].[physical_device_name]
			,[backup_size_mb]=CAST(([B].[backup_size]/1024.00)/1024.00 AS NUMERIC(20,2))
			,[compressed_backup_size_mb]=CAST(([B].[compressed_backup_size]/1024.00)/1024.00 AS NUMERIC(20,2))
			,[compression_ratio]=CAST((([B].[backup_size]-[B].[compressed_backup_size])/[B].[backup_size])*100.00 AS NUMERIC(5,2))
		FROM [master].[sys].[databases] [D]
			INNER JOIN [msdb].[dbo].[backupset] [B]
				ON [D].[name] = [B].[database_name]
			LEFT JOIN [msdb].[dbo].[backupmediaset] [MS]
				ON [B].[media_set_id] = [MS].[media_set_id]
			LEFT JOIN [msdb].[dbo].[backupmediafamily] [M]
				ON [B].[media_set_id] = [M].[media_set_id]
		WHERE [D].[name] NOT IN ('tempdb')
			AND [B].[backup_start_date] BETWEEN @start_datetime AND @end_datetime
		ORDER BY [D].[name] ASC
			,[B].[backup_finish_date] DESC;

	SELECT [I].[instance_guid]
		,[O].[database_name]
		,[O].[backup_type]
		,[D1].[datetimeoffset] AS [backup_start_date]
		,[D2].[datetimeoffset] AS [backup_finish_date]
		,[O].[is_copy_only]
		,[O].[software_name]
		,[O].[user_name]
		,[O].[physical_device_name]
		,[O].[backup_size_mb]
		,[O].[compressed_backup_size_mb]
		,[O].[compression_ratio]
		,[C].[backup_check_full_hour]
		,[C].[backup_check_diff_hour]
		,[C].[backup_check_tran_hour]
	FROM @output [O]
		LEFT JOIN [checkmk].[config_database] [C]
			ON [O].[database_name] = [C].[name]
		CROSS APPLY [system].[get_instance_guid]() [I]
		CROSS APPLY [system].[get_datetimeoffset]([O].[backup_start_date]) [D1]
		CROSS APPLY [system].[get_datetimeoffset]([O].[backup_finish_date]) [D2]
	ORDER BY [backup_start_date], [backup_finish_date];

	IF (@update_execution_timestamp = 1)
		MERGE INTO [collector].[last_execution] AS [Target]
		USING (SELECT OBJECT_NAME(@@PROCID), @end_datetime) AS [Source]([object_name],[last_execution])
		ON [Target].[object_name] = [Source].[object_name]
		WHEN MATCHED THEN
			UPDATE SET [Target].[last_execution] = [Source].[last_execution]
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT ([object_name],[last_execution]) VALUES ([Source].[object_name],[Source].[last_execution]);
END;