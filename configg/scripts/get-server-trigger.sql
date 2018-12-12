SET NOCOUNT ON;

SELECT 'INSTANCE' AS [heading], 'Server Triggers' AS [subheading], '' AS [comment]

SELECT [T].[create_date]
		,[T].[modify_date]
		,[T].[is_disabled]
		,ISNULL([M].[definition],'Encrypted') AS [definition]
	FROM sys.server_triggers [T]
		INNER JOIN sys.server_sql_modules [M]
			ON [T].[object_id] = [M].[object_id]