SET NOCOUNT ON;
	
SELECT 'SQL AGENT' AS [heading], 'Properties' AS [subheading], '' AS [comment]
EXEC msdb.dbo.sp_get_sqlagent_properties 