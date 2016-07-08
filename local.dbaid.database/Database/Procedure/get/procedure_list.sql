/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [get].[procedure_list]
(
	@schema NVARCHAR(128)
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'EXEC ' + QUOTENAME([schema_name]) + '.' + QUOTENAME([procedure_name]) AS [cmd]
		,[schema_name] + '_' + [procedure_name] AS [name]
	FROM [setting].[procedure_list]
	WHERE [is_enabled] = 1
		AND [schema_name] = @schema
	ORDER BY [procedure_name]
END