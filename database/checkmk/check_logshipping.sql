/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[usp_check_logshipping]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_config TABLE([config_name] NVARCHAR(128), [ci_name] NVARCHAR(128), [check_value] SQL_VARIANT, [check_change_alert] VARCHAR(10));
	DECLARE @check_output TABLE([message] NVARCHAR(4000),[state] NVARCHAR(8));

	DECLARE @primarycount INT;
	DECLARE @secondarycount INT;
	DECLARE @curdate_utc DATETIME;

	SELECT @curdate_utc = GETUTCDATE();

	SELECT @primarycount = COUNT(*)
	FROM [msdb].[dbo].[log_shipping_monitor_primary] [L]
		INNER JOIN [checkmk].[configuration_database] [C]
				ON [L].[primary_database] = [C].[name] COLLATE Database_Default
	WHERE [C].[logshipping_check_enabled] = 1;

	SELECT @secondarycount = COUNT(*)
	FROM [msdb].[dbo].[log_shipping_monitor_secondary] [L]
		INNER JOIN [checkmk].[configuration_database] [C]
				ON [L].[primary_database] = [C].[name] COLLATE Database_Default
	WHERE [C].[logshipping_check_enabled] = 0;

	INSERT INTO @check_output
		SELECT N'database=' 
			+ QUOTENAME([L].[primary_database]) COLLATE Database_Default 
			+ N'; role=PRIMARY; last_backup_minago=' 
			+ CAST(DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) AS NVARCHAR(10)) AS [message]
			,CASE WHEN DATEDIFF(HOUR, [L].[last_backup_date_utc], @curdate_utc) >= [C].[logshipping_check_hour]  
				THEN [C].[logshipping_check_alert] ELSE N'OK' END AS [state]
		FROM [msdb].[dbo].[log_shipping_monitor_primary] [L]
			INNER JOIN [checkmk].[configuration_database] [C]
					ON [L].[primary_database] = [C].[name] COLLATE Database_Default
		WHERE [C].[logshipping_check_enabled] = 1
			AND DATEDIFF(MINUTE, [L].[last_backup_date_utc], @curdate_utc) > [L].[backup_threshold]
		UNION ALL
		SELECT N'database=' + QUOTENAME([L].[secondary_database]) COLLATE Database_Default 
			+ N'; role=SECONDARY; primary_source=' + QUOTENAME([L].[primary_server]) 
			+ N'.' + QUOTENAME([L].[primary_database])
			+ N'; last_restore_minago=' + CAST(DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) AS NVARCHAR(10)) AS [message]
			,CASE WHEN DATEDIFF(HOUR, [L].[last_restored_date_utc], @curdate_utc) >= [C].[logshipping_check_hour] 
				THEN [C].[logshipping_check_alert] ELSE N'OK' END AS [state]
		FROM [msdb].[dbo].[log_shipping_monitor_secondary] [L]
			INNER JOIN [checkmk].[configuration_database] [C]
					ON [L].[secondary_database] = [C].[name] COLLATE Database_Default
		WHERE [C].[logshipping_check_enabled] = 1
			AND DATEDIFF(MINUTE, [L].[last_restored_date_utc], @curdate_utc) > [L].[restore_threshold]
		ORDER BY [message];

	IF (SELECT COUNT(*) FROM @check_output) < 1 AND (@primarycount > 0 OR @secondarycount > 0)
		INSERT INTO @check_output 
		VALUES(CAST(@primarycount AS NVARCHAR(10)) +  N' primary database(s), ' + CAST(@secondarycount AS NVARCHAR(10)) +  N' secondary database(s), ',N'NA');
	ELSE IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output 
		VALUES(N'Logshipping is currently not configured.',N'NA');

	SELECT [message], [state] FROM @check_output;
END