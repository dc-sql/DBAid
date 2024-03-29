﻿/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Backup]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @client VARCHAR(128);
	DECLARE @dbname VARCHAR(200);

	SELECT @client = REPLACE(REPLACE(REPLACE(CAST(SERVERPROPERTY('ServerName') AS SYSNAME)+[setting],'@','_'),'.','_'),'\','#')  
	FROM [deprecated].[tbparameters] 
	WHERE [parametername] = 'Client_domain';

	-- Table for storing results
	DECLARE @max_backup_dates TABLE ([DB_Name] NVARCHAR(255),[Start_Date] DATETIME);

	DECLARE @restoredbs TABLE ([DB_Name] NVARCHAR(255));

	INSERT @max_backup_dates
		SELECT CAST([database_name] AS VARCHAR(255)) AS [DB_Name], 
		MAX([backup_start_date]) AS [Start_Date] 
		FROM [msdb].[dbo].[backupset]
		WHERE [type] = 'D' 
		  AND [server_name] = CAST(SERVERPROPERTY('SERVERNAME') AS SYSNAME) --> GB 21/07/2009
		GROUP BY [database_name]
		ORDER BY [database_name] ASC;

	INSERT @restoredbs
	SELECT DISTINCT [destination_database_name]
	FROM [msdb].[dbo].[restorehistory]
	WHERE [restore_date] >= DATEADD(dd, -1, GETDATE())
	  AND [restore_type] = 'D';

	SELECT @client AS [Servername]
		,ISNULL([db].[name],[mbd].[DB_Name]) AS [DatabaseName]
		,ISNULL([Start_Date],'') AS [Date]
		,CASE 
			WHEN ([db].[crdate] > DATEADD(DAY, -1, GETDATE())) THEN 'New database'  --Database less than a day old
			WHEN ([rh].[DB_Name] IS NOT NULL) AND [tbpr].[setting] IS NULL THEN 'Restored' --Database was restored and not excluded from report.
			WHEN ([rh].[DB_Name] IS NOT NULL) AND [tbpr].[setting] = 1 THEN 'Exclude from restored database report' --Database was restored and excluded from report.
			WHEN [tbp].[setting] = 0 OR [LS].[secondary_database] IS NOT NULL OR DATABASEPROPERTYEX([db].[name],'Status') = N'RESTORING' THEN 'Backup not required' --Covering log shipped and readonly databases.
			WHEN DATABASEPROPERTYEX([db].[name],'Updateability') = N'READ_ONLY' THEN 'Read only database' --Read only database.
			WHEN DATABASEPROPERTYEX([db].[name],'IsInStandBy') = 1 THEN 'Standby database' --Standby database.
			WHEN DATABASEPROPERTYEX([db].[name],'Status') = N'OFFLINE' AND ([tbpo].[status] <> 1 OR [tbpo].[status] IS NULL) THEN 'IsOffline database' --Off line database.
			WHEN DATABASEPROPERTYEX([db].[name],'Status') = N'OFFLINE' AND [tbpo].[status] = 1 THEN 'OK' --Ignore offline database if "excluded_from_Monitoring_DBName" is set in [deprecated].[tbparameters].
			WHEN ([mbd].[DB_Name] IS NULL AND [db].[crdate] < DATEADD(DAY, -1, GETDATE())) THEN 'Never backed up' --Database has not backup date and is over a day old
			WHEN ([db].[name] IS NULL) THEN 'Deleted' -- The database does not exsist in the sysdatabase table
			WHEN ([Start_Date] >= GETDATE() - ISNULL(CONVERT(INT, [tbp].[setting]), 1)) THEN 'OK' -- The backup is not older than the retention period set in the tbparameter table
			WHEN ([Start_Date] < GETDATE() - ISNULL(CONVERT(INT, [tbp].[setting]), 1)) THEN 'Backup Due' -- Backup older than than the retention period set in the tbparameter table.
			ELSE '****' -- Catch all
			END AS [Status]
		,GETDATE() AS [checkdate] -- Date of the check
	FROM [master].[dbo].[sysdatabases] [db]
		FULL OUTER JOIN @max_backup_dates [mbd] 
			ON db.[name] = mbd.[DB_Name] COLLATE database_default
		LEFT JOIN [deprecated].[tbparameters] [tbp]
			ON db.[name] = [tbp].[parametername] COLLATE database_default
				AND [tbp].[comments] LIKE 'Database Backup Frequency (Days)'
		LEFT JOIN @restoredbs [rh]
			ON [db].[name] = [rh].[DB_Name] COLLATE database_default
		LEFT JOIN [msdb].[dbo].[log_shipping_monitor_secondary] [LS]
			ON [db].[name] = [LS].[secondary_database] COLLATE database_default
		LEFT JOIN [deprecated].[tbparameters] [tbpr] 
			ON [db].[name] = [tbpr].[parametername] COLLATE database_default
				AND [tbpr].[comments] like 'Exclude from restored database report'
		LEFT JOIN [deprecated].[tbparameters] [tbpo] 
			ON [db].[name] = [tbpo].[setting] COLLATE database_default
				AND [tbpo].[parametername] LIKE 'excluded_from_Monitoring_DBName'
	WHERE NOT ([db].[name] IS NULL AND [Start_Date] < GETDATE() - (ISNULL(CONVERT(INT, [tbp].[setting]), 1) + 1)) -- Remove all that were deleted over a day ago.
	   OR [db].[name] LIKE 'tempdb'
	ORDER BY [Status]
		,[Start_Date] DESC;

	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
			UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;

	REVERT;
END
GO