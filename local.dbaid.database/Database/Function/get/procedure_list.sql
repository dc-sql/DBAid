CREATE FUNCTION [get].[procedure_list]
(
	@schema NVARCHAR(128)
)
RETURNS TABLE
RETURN
(
	SELECT QUOTENAME([schema_name]) + '.' + QUOTENAME([procedure_name]) AS [procedure]
	FROM [setting].[procedure_list]
	WHERE [is_enabled] = 1
		AND [schema_name] = @schema
)
