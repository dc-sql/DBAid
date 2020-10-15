/*



*/

CREATE FUNCTION [system].[get_instance_guid]()
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT TOP(1) CAST([value] AS UNIQUEIDENTIFIER) AS [instance_guid]
	FROM [system].[configuration] 
	WHERE [key] = 'INSTANCE_GUID' COLLATE Latin1_General_CI_AS
)
