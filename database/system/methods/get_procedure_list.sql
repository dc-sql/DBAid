/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[get_procedure_list]
(
	@schema SYSNAME
)
RETURNS TABLE
WITH ENCRYPTION
RETURN (
	SELECT QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) AS [procedure]
	FROM sys.objects
	WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = @schema
)

