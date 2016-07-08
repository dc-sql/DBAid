/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));
	
	DECLARE @onlinecount INT;
	DECLARE @redstorecount INT;
	DECLARE @recovercount INT;

	SELECT @onlinecount = COUNT(*)
	FROM [sys].[databases] [D]
		INNER JOIN [setting].[check_database] [C] 
			ON [D].[database_id] = [C].[database_id]
	WHERE [C].[is_enabled] = 1
		AND [D].[state] IN (0);

	SELECT @redstorecount = COUNT(*)
	FROM [sys].[databases] [D]
		INNER JOIN [setting].[check_database] [C] 
			ON [D].[database_id] = [C].[database_id]
	WHERE [C].[is_enabled] = 1
		AND [D].[state] IN (1);

	SELECT @recovercount = COUNT(*)
	FROM [sys].[databases] [D]
		INNER JOIN [setting].[check_database] [C] 
			ON [D].[database_id] = [C].[database_id]
	WHERE [C].[is_enabled] = 1
		AND [D].[state] IN (2);

	INSERT INTO @check
		SELECT QUOTENAME([D].[name]) COLLATE Database_Default 
			+ N'=' 
			+ UPPER([D].[state_desc]) COLLATE Database_Default AS [message]
			,CASE WHEN [D].[state] NOT IN (0,1,2) THEN [C].[change_state_alert] ELSE N'OK' END AS [state]
		FROM [sys].[databases] [D]
			INNER JOIN [setting].[check_database] [C] 
				ON [D].[database_id] = [C].[database_id]
		WHERE [C].[is_enabled] = 1
			AND [D].[state] NOT IN (0,1,2)
		ORDER BY [D].[name];

		IF (SELECT COUNT(*) FROM @check) < 1
			INSERT INTO @check 
			VALUES(CAST(@onlinecount AS NVARCHAR(10)) + N' online, ' + CAST(@redstorecount AS NVARCHAR(10)) + N' restoring, ' + CAST(@recovercount AS NVARCHAR(10)) + N' recovering.'
				,N'NA');

		SELECT [message], [state] FROM @check
END
