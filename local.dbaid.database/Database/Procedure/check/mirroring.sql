/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[mirroring]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_config TABLE([config_name] NVARCHAR(128), [ci_name] NVARCHAR(128), [check_value] SQL_VARIANT, [check_change_alert] VARCHAR(10));
	DECLARE @check_output TABLE([message] NVARCHAR(4000),[state] NVARCHAR(8));

	INSERT INTO @check
	SELECT N'database=' + QUOTENAME([D].[name]) COLLATE Database_Default
		+ N'; state=' + UPPER([M].[mirroring_state_desc]) COLLATE Database_Default
		+ N'; expected_role=' + UPPER([C].[expected_mirror_role]) COLLATE Database_Default
		+ N'; current_role=' + UPPER([M].[mirroring_role_desc]) COLLATE Database_Default AS [message]
		,CASE WHEN ([M].[mirroring_state] NOT IN (2,4) OR [C].[expected_mirror_role] != [M].[mirroring_role_desc] COLLATE Database_Default) THEN [C].[check_mirror_state]	ELSE N'OK' END AS [state]
	FROM [master].[sys].[databases] [D]
		INNER JOIN [master].[sys].[database_mirroring] [M]
			ON [D].[database_id] = [M].[database_id]
		INNER JOIN [setting].[check_database] [C]
			ON [D].[database_id] = [C].[database_id]
	WHERE [C].[check_mirror_enabled] = 1
		AND [M].[mirroring_guid] IS NOT NULL;

	IF (SELECT COUNT(*) FROM @check) < 1
		INSERT INTO @check VALUES(N'Mirroring is currently not configured.',N'NA');

	SELECT [message], [state] FROM @check;
END