/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([message] NVARCHAR(4000),[state] NVARCHAR(8));
	DECLARE @onlinecount INT, @restorecount INT, @recovercount INT;

	INSERT INTO @check_output
		SELECT QUOTENAME([D].[name]) COLLATE Database_Default 
			+ '=' + UPPER([D].[state_desc]) COLLATE Database_Default AS [message]
			,CASE WHEN [D].[state] NOT IN (0,1,2) THEN [C].[database_check_alert] ELSE 'OK' END AS [state]
		FROM [sys].[databases] [D]
			INNER JOIN [checkmk].[configuration_database] [C] 
				ON [D].[name] = [C].[name]
		WHERE [C].[database_check_enabled] = 1
		ORDER BY [D].[name];

	IF (SELECT COUNT(*) FROM @check_output WHERE [state] != 'OK') = 0
	BEGIN
		SELECT @onlinecount = COUNT([state]) FROM sys.databases WHERE [state] = 0;
		SELECT @restorecount = COUNT([state]) FROM sys.databases WHERE [state] = 1;
		SELECT @recovercount = COUNT([state]) FROM sys.databases WHERE [state] = 2;

		INSERT INTO @check_output 
		VALUES(CAST(@onlinecount AS NVARCHAR(10)) + ' online; ' 
			+ CAST(@restorecount AS NVARCHAR(10)) + ' restoring; ' 
			+ CAST(@recovercount AS NVARCHAR(10)) + ' recovering','NA');
	END

	SELECT [message], [state] FROM @check_output WHERE [state] != 'OK';
END
