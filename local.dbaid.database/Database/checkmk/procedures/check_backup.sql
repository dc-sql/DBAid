/*



*/

CREATE PROCEDURE [checkmk].[check_backup]
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @backup_enabled INT, @backup_disabled INT, @major_version INT;
	DECLARE @preferred_backup TABLE ([name] sysname, [preferred_backup] BIT);
	DECLARE @last_backup TABLE ([name] sysname, [full_backup_date] DATETIME, [diff_backup_date] DATETIME, [tran_backup_date] DATETIME);
	DECLARE @check_output TABLE([state] VARCHAR(8), [message] NVARCHAR(4000));

	SELECT @major_version = [major] FROM [system].[get_product_version]();

	IF @major_version >= 11
	BEGIN
		INSERT INTO @preferred_backup
			EXEC sp_executesql N'SELECT [name], [sys].[fn_hadr_backup_is_preferred_replica]([name]) AS [preferred_backup] FROM [sys].[databases]';
	END

	;WITH [LastBackup]
	AS 
	(
		SELECT ROW_NUMBER() OVER (PARTITION BY [DB].[name], [B].[type] ORDER BY [B].[backup_finish_date] DESC) AS [row]
			,[DB].[name]
			,CASE WHEN [B].[type] = 'D' THEN [B].[backup_finish_date] ELSE NULL END AS [full_backup_date]
			,CASE WHEN [B].[type] = 'I' THEN [B].[backup_finish_date] ELSE NULL END AS [diff_backup_date]
			,CASE WHEN [B].[type] = 'L' THEN [B].[backup_finish_date] ELSE NULL END AS [tran_backup_date]
		FROM [sys].[databases] [DB] 
			LEFT JOIN [msdb].[dbo].[backupset] [B]
				ON [DB].[name] = [B].[database_name] COLLATE DATABASE_DEFAULT
			OUTER APPLY(SELECT [preferred_backup] FROM @preferred_backup WHERE [name] = [DB].[name] COLLATE DATABASE_DEFAULT) AS [AG]
		WHERE ([AG].[preferred_backup] = 1 OR [AG].[preferred_backup] IS NULL)
	)
	INSERT INTO @last_backup
		SELECT [name]
			,MAX([full_backup_date])
			,MAX([diff_backup_date])
			,MAX([tran_backup_date])
		FROM [LastBackup] 
		WHERE [row] = 1
		GROUP BY [name];

	INSERT INTO @check_output
		SELECT CASE WHEN ([C].[backup_check_full_hour] IS NOT NULL 
					AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) 
					AND ISNULL([LB].[full_backup_date], 0) < DATEADD(HOUR, -[C].[backup_check_full_hour], GETDATE()))
				OR ([C].[backup_check_diff_hour] IS NOT NULL 
					AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) 
					AND ISNULL([LB].[full_backup_date], 0) < DATEADD(HOUR, -[C].[backup_check_diff_hour], GETDATE()) 
					AND ISNULL([LB].[diff_backup_date], 0) < DATEADD(HOUR, -[C].[backup_check_diff_hour], GETDATE()))
				OR ([C].[backup_check_tran_hour] IS NOT NULL 
					AND [DB].[create_date] < DATEADD(DAY, -1, GETDATE()) 
					AND [DB].[recovery_model] IN (1,2) 
					AND ISNULL([LB].[tran_backup_date], 0) < DATEADD(HOUR, -[C].[backup_check_tran_hour], GETDATE()))
				THEN [C].[backup_check_alert]
				ELSE 'OK' END AS [state]
			,QUOTENAME([C].[name]) 
			+ N'; recovery_model=' 
			+ [DB].[recovery_model_desc] COLLATE DATABASE_DEFAULT
			+ CASE 
				WHEN [C].[backup_check_full_hour] IS NOT NULL 
				THEN N'; last_full=' 
					+ CASE
					WHEN [LB].[full_backup_date] IS NULL 
					THEN N'NEVER' 
					ELSE CONVERT(VARCHAR(20), [LB].[full_backup_date], 120) END
				ELSE '' END
			+ CASE 
				WHEN [C].[backup_check_diff_hour] IS NOT NULL 
				THEN N'; last_diff=' 
					+ CASE
					WHEN [LB].[diff_backup_date] IS NULL 
					THEN N'NEVER' 
					ELSE CONVERT(VARCHAR(20), [LB].[diff_backup_date], 120) END
				ELSE N'' END
			+ CASE 
				WHEN [C].[backup_check_tran_hour] IS NOT NULL 
				THEN N'; last_tran=' 
					+ CASE
					WHEN [LB].[tran_backup_date] IS NULL 
					THEN N'NEVER' 
					ELSE CONVERT(VARCHAR(20), [LB].[tran_backup_date], 120) END
				ELSE N'' END
			AS [message]
		FROM sys.databases [DB]
			INNER JOIN [checkmk].[config_database] [C]
				ON [DB].[name] = [C].[name] COLLATE DATABASE_DEFAULT
			LEFT JOIN @last_backup [LB]
				ON [DB].[name] = [LB].[name] COLLATE DATABASE_DEFAULT
		WHERE [C].[backup_check_enabled] = 1
		  AND [DB].[name] <> N'tempdb'
		  AND [DB].[state_desc] = N'ONLINE'
		  AND [DB].[is_in_standby] = 0;

	IF (SELECT COUNT(*) FROM @check_output WHERE [state] != 'OK') = 0
	BEGIN
		SELECT @backup_enabled = COUNT(*) FROM [checkmk].[config_database] WHERE [backup_check_enabled] = 1 AND [name] <> N'tempdb';
		SELECT @backup_disabled = COUNT(*) FROM [checkmk].[config_database] WHERE [backup_check_enabled] = 0 AND [name] <> N'tempdb';

		INSERT INTO @check_output VALUES('NA', N'Monitoring databases for backup(s)'
			+ N'; enabled=' + CAST(@backup_enabled AS NVARCHAR(8)) 
			+ N'; disabled=' + CAST(@backup_disabled AS NVARCHAR(8)));
	END

	SELECT [state], [message] FROM @check_output WHERE [state] != 'OK';

	IF (@writelog = 1)
	BEGIN
		DECLARE @ErrorMsg NVARCHAR(2048);
		DECLARE ErrorCurse CURSOR FAST_FORWARD FOR 
			SELECT [state] + N' - ' + OBJECT_NAME(@@PROCID) + N' - ' + [message] 
			FROM @check_output 
			WHERE [state] NOT IN ('NA','OK');

		OPEN ErrorCurse;
		FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;

		WHILE (@@FETCH_STATUS=0)
		BEGIN
			EXEC xp_logevent 54321, @ErrorMsg, 'WARNING';  
			FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;
		END

		CLOSE ErrorCurse;
		DEALLOCATE ErrorCurse;
	END
END
