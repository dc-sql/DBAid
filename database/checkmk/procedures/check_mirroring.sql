/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_mirroring]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([state] VARCHAR(8), [message] VARCHAR(4000));

	INSERT INTO @check_output
	SELECT CASE WHEN ([M].[mirroring_state] NOT IN (2,4) OR [C].[mirroring_check_role] != [M].[mirroring_role_desc] COLLATE DATABASE_DEFAULT) 
			THEN [C].[mirroring_check_alert] ELSE 'OK' END AS [state]
		,'database=' + QUOTENAME([D].[name]) COLLATE DATABASE_DEFAULT
		+ '; state=' + UPPER([M].[mirroring_state_desc]) COLLATE DATABASE_DEFAULT
		+ '; expected_role=' + UPPER([C].[mirroring_check_role]) COLLATE DATABASE_DEFAULT
		+ '; current_role=' + UPPER([M].[mirroring_role_desc]) COLLATE DATABASE_DEFAULT AS [message]
	FROM [master].[sys].[databases] [D]
		INNER JOIN [master].[sys].[database_mirroring] [M]
			ON [D].[database_id] = [M].[database_id]
		INNER JOIN [checkmk].[config_database] [C]
			ON [D].[name] = [C].[name] COLLATE DATABASE_DEFAULT
	WHERE [C].[mirroring_check_enabled] = 1
		AND [M].[mirroring_guid] IS NOT NULL;

	IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output VALUES('NA', 'Mirroring is currently not configured.');

	SELECT [state], [message] FROM @check_output;
END