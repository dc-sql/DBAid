/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[usp_check_backup]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @full_backup INT
		,@diff_backup INT
		,@log_backup INT
		,@major_version INT;

	DECLARE @preferred_backup TABLE 
		([db_name] SYSNAME
		,[preferred_backup] BIT);

	DECLARE @last_backup TABLE 
		([db_name] SYSNAME
		,[db_create_date] DATETIME
		,[db_recovery_model] TINYINT
		,[full_backup_date] DATETIME
		,[diff_backup_date] DATETIME
		,[tran_backup_date] DATETIME);

	DECLARE @check_output TABLE
		([message] NVARCHAR(4000)
		,[state] NVARCHAR(8));

	SELECT @major_version = [major] 
	FROM [system].[udf_get_product_version]();

	IF @major_version >= 11
	BEGIN
		INSERT INTO @preferred_backup
		EXEC sp_executesql N'SELECT [name], [sys].[fn_hadr_backup_is_preferred_replica]([name]) AS [preferred_backup] FROM [sys].[databases]'
	END

	;WITH [Backup]
	AS 
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [DB].[name], [BS].[type] ORDER BY [BS].[backup_finish_date] DESC) AS [row]
			,[DB].[name]
			,[DB].[create_date]
			,[DB].[recovery_model] /* 1 = FULL, 2 = BULK_LOGGED, 3 = SIMPLE */
			,CASE WHEN [BS].[type] = 'D' THEN [BS].[backup_finish_date] ELSE NULL END AS [full_backup_date]
			,CASE WHEN [BS].[type] = 'I' THEN [BS].[backup_finish_date] ELSE NULL END AS [diff_backup_date]
			,CASE WHEN [BS].[type] = 'L' THEN [BS].[backup_finish_date] ELSE NULL END AS [tran_backup_date]
		FROM [sys].[databases] [DB] 
			LEFT JOIN [msdb].[dbo].[backupset] [BS]
				ON [DB].[name] = [BS].[database_name]
			OUTER APPLY(SELECT [preferred_backup] FROM @preferred_backup WHERE [db_name] = [CC].[ci_name]) AS [AG]
		WHERE ([AG].[preferred_backup] = 1 OR [AG].[preferred_backup] IS NULL)
	)
	INSERT INTO @last_backup
		SELECT [name]
			,[create_date]
			,[recovery_model]
			,SUM([full_backup_date])
			,SUM([diff_backup_date])
			,SUM([tran_backup_date])
		FROM [Backup]
		WHERE [row] = 1
		GROUP BY [name]
			,[create_date]
			,[recovery_model]
		ORDER BY [name];

	SELECT [LB].[db_name]
		,[LB].[db_create_date]
		,[LB].[db_recovery_model]
		,[LB].[diff_backup_date]
		,[LB].[full_backup_date]
		,[LB].[tran_backup_date]
		,[CB].[full_frequency_hour]
		,[CB].[diff_frequency_hour]
		,[CB].[tran_frequency_minute]
		,[CB].[alert_full_state]
		,[CB].[alert_diff_state]
		,[CB].[alert_tran_state]
	FROM @last_backup [LB]
		INNER JOIN [checkmk].[tbl_config_backup] [CB]
			ON [LB].[db_name] = [CB].[db_name]

	IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output VALUES('Monitoring database backup(s) for full=' 
			+ CAST(@full_backup AS VARCHAR(3)) + N'; diff=' 
			+ CAST(@diff_backup AS VARCHAR(3)) + N'; tlog=' 
			+ CAST(@log_backup AS VARCHAR(3)), N'NA');

	SELECT [message], [state] 
	FROM @check_output;
END
