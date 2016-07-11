﻿/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[checkdb]
WITH ENCRYPTION
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

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

		EXECUTE [dbo].[foreachdb] N'USE [?];
									INSERT #dbccinfo
										(ParentObject, 
										Object, 
										Field, 
										Value)
									EXEC (''DBCC DBINFO() WITH TABLERESULTS, NO_INFOMSGS'');
									UPDATE #dbccinfo SET [dbname] = N''?'' WHERE [dbname] IS NULL;';
	REVERT;
	REVERT;

	;WITH [CheckDB] AS
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
				+ QUOTENAME([DbName])
				+ N'; last_checkdb=' 
				+ CASE
					WHEN REPLACE(CONVERT(NVARCHAR(20), [CheckDB].[Value], 120), N' ', N'T') = '1900-01-01T00:00:00.' THEN 'NEVER'
					ELSE REPLACE(CONVERT(NVARCHAR(20), [CheckDB].[Value], 120), N' ', N'T')
				  END
				+ N'; checkdb_missed=' 
				+ CASE
					WHEN REPLACE(CONVERT(NVARCHAR(20), [CheckDB].[Value], 120), N' ', N'T') = '1900-01-01T00:00:00.' THEN 'ALL'
					ELSE CAST(CAST(DATEDIFF(HOUR, [CheckDB].[Value], GETDATE()) / [D].[check_integrity_since_hour] AS INT) AS VARCHAR(5))
				  END
			,[S].[state]
		FROM [CheckDB] 
			INNER JOIN [setting].[check_database] [D]
				ON [CheckDB].[DbName] = [D].[db_name] COLLATE Database_Default
			CROSS APPLY (SELECT CASE WHEN ([CheckDB].[Value] IS NULL OR DATEDIFF(HOUR, [CheckDB].[Value], GETDATE()) > ([D].[check_integrity_since_hour])) THEN [D].[check_integrity_state] ELSE N'OK' END AS [state]) [S]
		WHERE [D].[check_integrity_since_hour] > 0
			AND [S].[state] NOT IN (N'OK')
		ORDER BY [CheckDB].[DbName]

		IF (SELECT COUNT(*) FROM @check) < 1
			INSERT INTO @check 
			VALUES(CAST(@dbcheckdb AS NVARCHAR(10)) + N' database(s) monitored, ' + CAST(@dbnotcheckdb AS NVARCHAR(10)) + N' database(s) opted-out'
				,N'NA');

		SELECT [message], [state] 
		FROM @check
	END