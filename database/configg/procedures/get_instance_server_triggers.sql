/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_instance_server_triggers]
WITH ENCRYPTION
AS
BEGIN 
	SET NOCOUNT ON;

	SELECT 'Instance' AS [heading], 'Server Triggers' AS [subheading], '' AS [comment]

	SELECT [T].[create_date]
			,[T].[modify_date]
			,[T].[is_disabled]
			,ISNULL([M].[definition],'Encrypted') AS [definition]
		FROM sys.server_triggers [T]
			INNER JOIN sys.server_sql_modules [M]
				ON [T].[object_id] = [M].[object_id]
END