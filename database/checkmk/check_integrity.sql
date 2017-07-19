/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_integrity]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @dbcheckdb INT, @dbnotcheckdb INT;
	DECLARE @check_output TABLE ([message] NVARCHAR(4000), [state] NVARCHAR(8));

	IF OBJECT_ID('tempdb..#dbccinfo') IS NOT NULL 
		DROP TABLE #dbccinfo;

	CREATE TABLE #dbccinfo 
		([parent_object] NVARCHAR(255)
		,[object] NVARCHAR(255)
		,[field] NVARCHAR(255)
		,[value] NVARCHAR(255)
		,[db_name] NVARCHAR(128) NULL);

	EXECUTE [system].[execute_foreach_db] N'USE [?];
		INSERT #dbccinfo ([parent_object], [object], [field], [value]) EXEC (''DBCC DBINFO() WITH TABLERESULTS, NO_INFOMSGS'');
		UPDATE #dbccinfo SET [db_name] = N''?'' WHERE [db_name] IS NULL;';

	;WITH [DbccDataSet] AS
	(
		SELECT [CD].[name]
			,[CD].[integrity_check_alert]
			,CAST([CD].[integrity_check_hour] AS NUMERIC(5,2)) AS [integrity_check_hour]
			,[DB].[create_date] AS [db_create_date]
			,CAST(REPLACE([DI].[value], '.', '') AS DATETIME) AS [last_dbcc_datetime]
		FROM [sys].[databases] [DB]
			LEFT JOIN #dbccinfo [DI]
				ON [DB].[name] = [DI].[db_name]
			LEFT JOIN [checkmk].[configuration_database] [CD]
					ON [DB].[database_id] = [CD].[database_id]
					AND [DB].[name] = [CD].[name] COLLATE Database_Default
		WHERE [DI].[field] = 'dbi_dbccLastKnownGood'
			AND [CD].[integrity_check_enabled] = 1
	)
	INSERT INTO @check_output
		SELECT N'database=' 
			+ QUOTENAME([name])
			+ N'; last_checkdb=' 
			+ CASE WHEN [last_dbcc_datetime] IS NULL OR [last_dbcc_datetime] < [db_create_date] THEN 'NEVER'
				ELSE CONVERT(NVARCHAR(20), [last_dbcc_datetime], 120) END AS [message]
			,CASE WHEN [last_dbcc_datetime] < DATEADD(HOUR, -[integrity_check_hour], GETDATE()) 
					AND [db_create_date] < DATEADD(HOUR, -[integrity_check_hour], GETDATE()) THEN [integrity_check_alert] 
				ELSE N'OK' END AS [state]
		FROM [DbccDataSet]
		ORDER BY [name];

		IF (SELECT COUNT(*) FROM @check_output WHERE [state] NOT IN (N'OK')) < 1
		BEGIN
			SELECT @dbcheckdb=COUNT(*) 
			FROM [checkmk].[configuration_database] 
			WHERE [integrity_check_enabled] = 1;

			SELECT @dbnotcheckdb=COUNT(*) 
			FROM [checkmk].[configuration_database] 
			WHERE [integrity_check_enabled] = 0;

			INSERT INTO @check_output 
			VALUES(CAST(@dbcheckdb AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@dbnotcheckdb AS NVARCHAR(10)) + N' database(s) opted-out',N'NA');
		END 

		SELECT [message], [state] 
		FROM @check_output 
		WHERE [state] NOT IN (N'OK')
END