/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[logshipping]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	DECLARE @primarycount INT;
	DECLARE @secondarycount INT;
	DECLARE @curdate_utc DATETIME;

	SELECT @curdate_utc = GETUTCDATE();

	SELECT @primarycount = COUNT(*)
	FROM [msdb].[dbo].[log_shipping_monitor_primary] [L]
		INNER JOIN [dbo].[config_database] [C]
				ON [L].[primary_database] = [C].[db_name] COLLATE Database_Default
	WHERE [C].[is_enabled] = 1

	SELECT @secondarycount = COUNT(*)
	FROM [msdb].[dbo].[log_shipping_monitor_secondary] [L]
		INNER JOIN [dbo].[config_database] [C]
				ON [L].[secondary_database] = [C].[db_name] COLLATE Database_Default
	WHERE [C].[is_enabled] = 1

	INSERT INTO @check
		SELECT N'database=' 
			+ QUOTENAME([L].[primary_database]) COLLATE Database_Default 
			+ N'; role=PRIMARY; last_backup_minago=' 
			+ CAST(DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) AS NVARCHAR(10)) AS [message]
			,CASE WHEN DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) > [L].[backup_threshold]  THEN [C].[change_state_alert] ELSE N'OK' END AS [state]
		FROM [msdb].[dbo].[log_shipping_monitor_primary] [L]
			INNER JOIN [dbo].[config_database] [C]
					ON [L].[primary_database] = [C].[db_name] COLLATE Database_Default
		WHERE [L].[threshold_alert_enabled] = 1
			AND DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) > [L].[backup_threshold]
		UNION ALL
		SELECT N'database=' + QUOTENAME([L].[secondary_database]) COLLATE Database_Default 
			+ N'; role=SECONDARY; primary_source=' + QUOTENAME([L].[primary_server]) 
			+ N'.' + QUOTENAME([L].[primary_database])
			+ N'; last_restore_minago=' + CAST(DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) AS NVARCHAR(10)) AS [message]
			,CASE WHEN DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) > [L].[restore_threshold] THEN [C].[change_state_alert] ELSE N'OK' END AS [state]
		FROM [msdb].[dbo].[log_shipping_monitor_secondary] [L]
			INNER JOIN [dbo].[config_database] [C]
					ON [L].[secondary_database] = [C].[db_name] COLLATE Database_Default
		WHERE [L].[threshold_alert_enabled] = 1
			AND DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) > [L].[restore_threshold]
		ORDER BY [message];

	IF (SELECT COUNT(*) FROM @check) < 1 AND (@primarycount > 0 OR @secondarycount > 0)
		INSERT INTO @check VALUES(CAST(@primarycount AS NVARCHAR(10)) +  N' primary database(s), ' + CAST(@secondarycount AS NVARCHAR(10)) +  N' secondary database(s), ',N'NA');
	ELSE IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(N'Logshipping is currently not configured.',N'NA');
	SELECT [message], [state] FROM @check;
END