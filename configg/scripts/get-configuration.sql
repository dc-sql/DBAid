SET NOCOUNT ON;

SELECT 'INSTANCE' AS [heading], 'Configurations' AS [subheading], '' AS [comment]

SELECT [name]
	,[value_in_use]
FROM [master].[sys].[configurations]