/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [system].[get_procedure_list]
(
	@schema SYSNAME,
	@filter NVARCHAR(20) = NULL
)
WITH ENCRYPTION
AS
BEGIN
	SELECT QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) AS [procedure]
	FROM sys.objects
	WHERE [type] = 'P' 
		AND SCHEMA_NAME([schema_id]) = @schema
		AND ([name] LIKE @filter OR @filter IS NULL)
END

