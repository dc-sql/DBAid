/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [control].[check]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT QUOTENAME([schema_name]) + '.' + QUOTENAME([procedure_name]) AS [cmd]
	FROM [dbo].[procedure]
	WHERE [is_enabled] = 1
		AND [schema_name] = N'check'
	ORDER BY [procedure_name]
END
