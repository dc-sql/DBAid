CREATE FUNCTION [get].[wmi_service_query]()
RETURNS @returntable TABLE
(
	[query] VARCHAR(MAX)
)
WITH ENCRYPTION, EXECUTE AS 'dbo'
BEGIN
	SELECT [query] FROM [setting].[wmi_service_query] WHERE [is_enabled] = 1;

	RETURN
END
