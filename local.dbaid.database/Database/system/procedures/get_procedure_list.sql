/*
Get a list of procedures in a schema. 

PARAMETERS
	INPUT
		@schema_name sysname
		returns list of all procedures in schema_name. Accepts wildcards. 
*/

CREATE PROCEDURE [system].[get_procedure_list]
(
    @schema_name sysname
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [procedure]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) 
    FROM sys.objects 
    WHERE [type] = 'P' 
        AND SCHEMA_NAME([schema_id]) LIKE @schema_name
END
