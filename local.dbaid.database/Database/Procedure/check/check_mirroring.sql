/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[mirroring]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	INSERT INTO @check
	SELECT N'database=' + QUOTENAME([D].[name]) COLLATE Database_Default
		+ N'; state=' + UPPER([M].[mirroring_state_desc]) COLLATE Database_Default
		+ N'; expected_role=' + UPPER([C].[mirroring_role]) COLLATE Database_Default
		+ N'; current_role=' + UPPER([M].[mirroring_role_desc]) COLLATE Database_Default AS [message]
		,CASE WHEN ([M].[mirroring_state] NOT IN (2,4) OR [C].[mirroring_role] != [M].[mirroring_role_desc] COLLATE Database_Default) THEN [C].[change_state_alert]	ELSE N'OK' END AS [state]
	FROM [master].[sys].[databases] [D]
		INNER JOIN [master].[sys].[database_mirroring] [M]
			ON [D].[database_id] = [M].[database_id]
		INNER JOIN [dbo].[config_database] [C]
			ON [D].[database_id] = [C].[database_id]
	WHERE [C].[is_enabled] = 1
		AND [M].[mirroring_guid] IS NOT NULL;

	REVERT;
	REVERT;

	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(N'Mirroring is currently not configured.',N'NA');

	SELECT [message], [state] FROM @check;

	REVERT;
END