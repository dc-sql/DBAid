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

	DECLARE @check TABLE([message] NVARCHAR(4000)
							,[state] NVARCHAR(8));

	DECLARE @dbcheckdb INT;
	DECLARE @dbnotcheckdb INT;

	SELECT @dbcheckdb=COUNT(*) FROM [setting].[check_database] WHERE [check_integrity_since_hour] > 0;
	SELECT @dbnotcheckdb=COUNT(*) FROM [setting].[check_database] WHERE [check_integrity_since_hour] = 0;
	
	IF OBJECT_ID('tempdb..#dbccinfo') IS NOT NULL 
	DROP TABLE #dbccinfo;

	CREATE TABLE #dbccinfo (
		[ParentObject] NVARCHAR(255),
		[Object] NVARCHAR(255),
		[Field] NVARCHAR(255),
		[Value] NVARCHAR(255),
		[DbName] NVARCHAR(128) NULL
	);

	EXECUTE [dbo].[foreach_db] N'USE [?];
		INSERT #dbccinfo
			(ParentObject, 
			Object, 
			Field, 
			Value)
		EXEC (''DBCC DBINFO() WITH TABLERESULTS, NO_INFOMSGS'');
		UPDATE #dbccinfo SET [dbname] = N''?'' WHERE [dbname] IS NULL;';

	;WITH [dbccinfo] AS
	(
		SELECT DISTINCT
				[Field] ,
				[Value] ,
				[DbName]
		FROM #dbccinfo
		WHERE [Field] = 'dbi_dbccLastKnownGood'
	)
	INSERT INTO @check
		SELECT N'database=' 
				+ QUOTENAME([DBCC].[DbName])
				+ N'; last_checkdb=' 
				+ CASE
					WHEN REPLACE(CONVERT(NVARCHAR(20), [DBCC].[Value], 120), N' ', N'T') = '1900-01-01T00:00:00.' THEN 'NEVER'
					ELSE REPLACE(CONVERT(NVARCHAR(20), [DBCC].[Value], 120), N' ', N'T')
				  END
				+ N'; checkdb_missed=' 
				+ CASE
					WHEN REPLACE(CONVERT(NVARCHAR(20), [DBCC].[Value], 120), N' ', N'T') = '1900-01-01T00:00:00.' THEN 'ALL'
					ELSE CAST(CAST(DATEDIFF(HOUR, [DBCC].[Value], GETDATE()) / [CD].[check_integrity_since_hour] AS INT) AS VARCHAR(5))
				  END
			,CASE WHEN ([DBCC].[Value] IS NULL OR DATEDIFF(HOUR, [DBCC].[Value], GETDATE()) > ([CD].[check_integrity_since_hour])) THEN [CS].[state_desc] ELSE N'OK' END AS [state]
		FROM [dbccinfo] [DBCC] 
			INNER JOIN [setting].[check_database] [CD]
				ON [DBCC].[DbName] = [CD].[db_name] COLLATE Database_Default
			INNER JOIN [setting].[check_state] [CS]
				ON [CD].[check_database_state] = [CS].[state_id]
		WHERE [CD].[check_integrity_since_hour] > 0
		ORDER BY [CheckDB].[DbName]

		IF (SELECT COUNT(*) FROM @check) < 1
			INSERT INTO @check 
			VALUES(CAST(@dbcheckdb AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@dbnotcheckdb AS NVARCHAR(10)) + N' database(s) opted-out',N'NA');

		SELECT [message], 
			[state] 
		FROM @check 
		WHERE [state] NOT IN (N'OK')
	END