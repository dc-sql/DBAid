/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[checkdb]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_config TABLE([config_name] NVARCHAR(128), [ci_name] NVARCHAR(128), [check_value] SQL_VARIANT, [check_change_alert] VARCHAR(10));
	DECLARE @check_output TABLE([message] NVARCHAR(4000),[state] NVARCHAR(8));

	DECLARE @dbcheckdb INT, @dbnotcheckdb INT;

	SELECT @dbcheckdb=COUNT(*) FROM [setting].[check_database] WHERE [check_integrity_since_hour] > 0;
	SELECT @dbnotcheckdb=COUNT(*) FROM [setting].[check_database] WHERE [check_integrity_since_hour] = 0;
	
	INSERT INTO @check_config
		SELECT [config_name]
			,[ci_name]
			,[check_value]
			,[check_change_alert]
		FROM [get].[check_configuration](OBJECT_NAME(@@PROCID), NULL, NULL);

	IF OBJECT_ID('tempdb..#dbccinfo') IS NOT NULL 
	DROP TABLE #dbccinfo;

	CREATE TABLE #dbccinfo (
		[parent_object] NVARCHAR(255),
		[object] NVARCHAR(255),
		[field] NVARCHAR(255),
		[value] NVARCHAR(255),
		[db_name] NVARCHAR(128) NULL
	);

	EXECUTE [dbo].[foreach_db] N'USE [?];
		INSERT #dbccinfo ([parent_object], [object], [field], [value])
		EXEC (''DBCC DBINFO() WITH TABLERESULTS, NO_INFOMSGS'');
		UPDATE #dbccinfo SET [db_name] = N''?'' WHERE [db_name] IS NULL;';

	;WITH [DbccDataSet] AS
	(
		SELECT DISTINCT [CC].[config_name] 
			,[CC].[ci_name]
			,CAST([CC].[check_value] AS NUMERIC(5,2)) AS [check_value]
			,[CC].[check_change_alert]
			,[DB].[create_date] AS [db_create_date]
			,CASE WHEN CAST(REPLACE([DI].[value], '.', '') AS DATETIME) < [db_create_date] THEN NULL 
				ELSE CAST(REPLACE([DI].[value], '.', '') AS DATETIME) END AS [last_dbcc_datetime]
		FROM [sys].[databases] [DB]
			LEFT JOIN #dbccinfo [DI]
				ON [DB].[name] = [DI].[DbName]
			LEFT JOIN @check_config [CC]
					ON 'checkdb_frequency_hour' = [CC].[config_name] COLLATE Database_Default
					AND [DI].[db_name] = [CC].[ci_name] COLLATE Database_Default
		WHERE [Field] = 'dbi_dbccLastKnownGood'
			AND [CC].[check_value] IS NOT NULL
	)
	INSERT INTO @check_output
		SELECT N'database=' 
			+ QUOTENAME([ci_name])
			+ N'; last_checkdb=' 
			+ CASE WHEN [last_dbcc_datetime] IS NULL THEN 'NEVER'
				ELSE CONVERT(NVARCHAR(20), [last_dbcc_datetime], 120) END
			,CASE WHEN ISNULL([last_dbcc_datetime], [db_create_date]) < DATEADD(HOUR, -[check_value], GETDATE()) THEN [check_change_alert] ELSE N'OK' END AS [state]
		FROM [DbccDataSet]
		ORDER BY [ci_name]

		IF (SELECT COUNT(*) FROM @check_output WHERE [state] NOT IN (N'OK')) < 1
			INSERT INTO @check_output 
			VALUES(CAST(@dbcheckdb AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@dbnotcheckdb AS NVARCHAR(10)) + N' database(s) opted-out',N'NA');

		SELECT [message], [state] 
		FROM @check_output 
		WHERE [state] NOT IN (N'OK')
END