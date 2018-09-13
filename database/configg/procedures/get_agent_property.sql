CREATE PROCEDURE [configg].[get_agent_property]
WITH ENCRYPTION
AS
BEGIN
	SELECT 'SQL AGENT' AS [heading], 'Properties' AS [subheading], '' AS [comment]

	EXEC msdb.dbo.sp_get_sqlagent_properties 
END
