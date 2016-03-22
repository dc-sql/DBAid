/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [control].[procedurelist]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'EXEC ' + QUOTENAME([schema_name]) + '.' + QUOTENAME([procedure_name]) AS [cmd]
		,[schema_name] + '_' + [procedure_name] AS [name]
	FROM [dbo].[procedure]
	WHERE [is_enabled] = 1
		AND [schema_name] IN ('fact','log','deprecated')
	ORDER BY [schema_name], [procedure_name]
END