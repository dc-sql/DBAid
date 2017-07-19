﻿/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [collector].[get_backup_history]
(
	@start_datetime DATETIME2 = NULL,
	@end_datetime DATETIME2 = NULL,
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @compression BIT;
	DECLARE @cmd VARCHAR(MAX);

	DECLARE @output TABLE ([database_id] INT,
							[database_name] NVARCHAR(128),
							[backup_type] CHAR(1),
							[is_copy_only] BIT,
							[backup_start_date] DATETIME,
							[backup_finish_date] DATETIME,
							[software_name] NVARCHAR(128),
							[user_name] NVARCHAR(128),
							[physical_device_name] NVARCHAR(260),
							[backup_size_mb] NUMERIC(20,2),
							[compressed_backup_size_mb] NUMERIC(20,2),
							[compression_ratio] NUMERIC(5,2),
							[encryptor_type] NVARCHAR(32),
							[encryptor_thumbprint] VARBINARY(20),
							[is_password_protected] BIT);

	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=ISNULL([last_execution], DATEADD(DAY,-1,GETDATE())) 
		FROM [collector].[last_execution] WHERE [object_name] = OBJECT_NAME(@@PROCID);
	END

	IF EXISTS (SELECT 1 FROM [msdb].[sys].[objects] [O] INNER JOIN [msdb].[sys].[columns] [C] ON [O].[object_id] = [C].[object_id] WHERE SCHEMA_NAME([O].[schema_id]) = N'dbo' AND [O].[name] = N'backupset' AND [C].[name] LIKE N'compressed_backup_size')
		SET @compression = 1;
	ELSE SET @compression = 0;

	SELECT @cmd = 'SELECT [D].[database_id],
			[D].[name] AS [database_name],
			[B].[type] AS [backup_type],
			[B].[is_copy_only],
			[B].[backup_start_date],
			[B].[backup_finish_date],
			[MS].[software_name],
			[B].[user_name],
			[M].[physical_device_name],
			CAST(([B].[backup_size]/1024.00)/1024.00 AS NUMERIC(20,2)) AS [backup_size_mb],'
		+ CASE WHEN (SELECT [COLUMN_NAME] FROM [msdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = 'backupset' AND [COLUMN_NAME] = 'compressed_backup_size') = 'compressed_backup_size' 
			THEN 'CAST(([B].[compressed_backup_size]/1024.00)/1024.00 AS NUMERIC(20,2)) AS [compressed_backup_size_mb],'
				+ 'CAST((([B].[backup_size]-[B].[compressed_backup_size])/[B].[backup_size])*100.00 AS NUMERIC(5,2)) AS [compression_ratio],' 
			ELSE 'NULL AS [compressed_backup_size_mb], NULL AS [compression_ratio],' END
		+ CASE WHEN (SELECT [COLUMN_NAME] FROM [msdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = 'backupset' AND [COLUMN_NAME] = 'encryptor_type') = 'encryptor_type' 
			THEN '[B].[encryptor_type],' 
			ELSE 'NULL AS [encryptor_type],' END
		+ CASE WHEN (SELECT [COLUMN_NAME] FROM [msdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = 'backupset' AND [COLUMN_NAME] = 'encryptor_thumbprint') = 'encryptor_thumbprint' 
			THEN '[B].[encryptor_thumbprint],' 
			ELSE 'NULL AS [encryptor_thumbprint],' END
		+ CASE WHEN (SELECT [COLUMN_NAME] FROM [msdb].[INFORMATION_SCHEMA].[COLUMNS] WHERE [TABLE_NAME] = 'backupset' AND [COLUMN_NAME] = 'Is_password_protected') = 'Is_password_protected' 
			THEN '[B].[Is_password_protected]' 
			ELSE 'NULL AS [Is_password_protected]' END
		+ CHAR(13) + CHAR(10) 
		+ 'FROM [master].[sys].[databases] [D]
			INNER JOIN [msdb].[dbo].[backupset] [B]
				ON [D].[name] = [B].[database_name]
			LEFT JOIN [msdb].[dbo].[backupmediaset] [MS]
				ON [B].[media_set_id] = [MS].[media_set_id]
			LEFT JOIN [msdb].[dbo].[backupmediafamily] [M]
				ON [B].[media_set_id] = [M].[media_set_id]
		WHERE [D].[name] != ''tempdb''
		ORDER BY [D].[name], [B].[backup_finish_date] DESC;';

	INSERT INTO @output 
		EXEC(@cmd);

	IF (@end_datetime IS NULL)
		SET @end_datetime = SYSDATETIME();

	SELECT [I].[instance_guid]
		,[D1].[datetimeoffset] AS [backup_start_date]
		,[D2].[datetimeoffset] AS [backup_finish_date]
		,[O].[database_name]
		,[O].[backup_type]
		,[O].[is_copy_only]
		,[O].[software_name]
		,[O].[user_name]
		,[O].[physical_device_name]
		,[O].[backup_size_mb]
		,[O].[compressed_backup_size_mb]
		,[O].[compression_ratio]
		,[O].[encryptor_type]
		,[O].[encryptor_thumbprint]
		,[O].[is_password_protected]
		,[backup_check_full_hour]
		,[backup_check_diff_hour]
		,[backup_check_tran_hour]
	FROM @output [O]
		LEFT JOIN [checkmk].[configuration_database] [C]
			ON [O].[database_name] = [C].[name]
		CROSS APPLY [system].[get_instance_guid]() [I]
		CROSS APPLY [system].[get_datetimeoffset]([O].[backup_start_date]) [D1]
		CROSS APPLY [system].[get_datetimeoffset]([O].[backup_finish_date]) [D2]
	WHERE [backup_start_date] BETWEEN @start_datetime AND @end_datetime
	ORDER BY [backup_start_date], [backup_finish_date];

	IF (@update_execution_timestamp = 1)
		UPDATE [collector].[last_execution] 
		SET [last_execution] = @end_datetime 
		WHERE [object_name] = OBJECT_NAME(@@PROCID);
END;