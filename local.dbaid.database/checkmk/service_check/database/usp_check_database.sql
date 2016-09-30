/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[usp_check_database]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([message] NVARCHAR(4000),[state] NVARCHAR(8));
	DECLARE @onlinecount INT, @restorecount INT, @recovercount INT;

	INSERT INTO @check_output
		SELECT QUOTENAME([D].[name]) COLLATE Database_Default 
			+ N'=' 
			+ UPPER([D].[state_desc]) COLLATE Database_Default AS [message]
			,CASE WHEN [D].[state] NOT IN (0,1,2) THEN [CS].[state_desc] ELSE 'OK' END AS [state]
		FROM [sys].[databases] [D]
			INNER JOIN [setting].[check_database] [CD] 
				ON [D].[database_id] = [CD].[database_id]
			INNER JOIN [setting].[check_state] [CS]
				ON [CD].[check_database_state] = [CS].[state_id]
		WHERE [CD].[check_database_enabled] = 1
		ORDER BY [D].[name];

		IF (SELECT COUNT(*) FROM @check_output WHERE [state] != 'OK') = 0
			INSERT INTO @check_output 
			VALUES(CAST(@onlinecount AS NVARCHAR(10)) + N' online; ' 
				+ CAST(@restorecount AS NVARCHAR(10)) + N' restoring; ' 
				+ CAST(@recovercount AS NVARCHAR(10)) + N' recovering',N'NA');

		SELECT [message], [state] FROM @check_output WHERE [state] != 'OK'
END
