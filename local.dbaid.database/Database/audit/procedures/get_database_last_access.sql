/*



*/

CREATE PROCEDURE [audit].[get_database_last_access]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @objects TABLE ([db_id] INT, [object_id] INT, [object_name] VARCHAR(128));
	DECLARE @last_access TABLE ([name] [nvarchar](128) NOT NULL
								,[last_access] [datetime] NULL
								,[last_server_restart] [datetime] NOT NULL);

	INSERT INTO @objects
		EXEC [system].[execute_foreach_db] N'SELECT DB_ID(''?'') AS [db_id], [object_id], [name] FROM [?].sys.objects WHERE [is_ms_shipped] = 0 AND [type] = ''U'';';

	INSERT INTO @last_access
		SELECT [db_name]
			,MAX([db_last_access]) AS [db_last_access]
			,[last_server_restart]
		FROM
		(SELECT [D].[name] AS [db_name],
			ISNULL([X].[last_user_seek],'19000101') AS [last_user_seek],
			ISNULL([X].[last_user_scan],'19000101') AS [last_user_scan],
			ISNULL([X].[last_user_lookup],'19000101') AS [last_user_lookup],
			ISNULL([X].[last_user_update],'19000101') AS [last_user_update],
			(SELECT [create_date] FROM sys.databases WHERE [name] = 'tempdb') AS [last_server_restart]
		FROM sys.databases [D]
			LEFT JOIN (SELECT [S].[database_id]
							,[S].[last_user_seek]
							,[S].[last_user_scan]
							,[S].[last_user_lookup]
							,[S].[last_user_update] 
						FROM sys.dm_db_index_usage_stats [S]
							INNER JOIN @objects [O]
								ON [S].[database_id] = [O].[db_id]
									AND [S].[object_id] = [O].[object_id]) [X]
				ON [D].[database_id] = [X].[database_id]
		WHERE [D].[name] NOT IN ('master', 'msdb', 'model', 'tempdb', '_dbaid')
			AND [D].[state] = 0
			AND [D].[is_in_standby] = 0) AS [source]
		UNPIVOT
		(
			[db_last_access] FOR [access_type] IN
			([last_user_seek], [last_user_scan], [last_user_lookup], [last_user_update])
		) AS [unpivot]
		GROUP BY [db_name]
		,[last_server_restart];

	MERGE [audit].[database_last_access] AS [target]
	USING (
	SELECT [name]
		,[last_access]
		,[last_server_restart]
	FROM @last_access
	) AS [source]
	ON ([target].[name] = [source].[name]) 
	WHEN MATCHED THEN
		UPDATE SET [target].[last_access] = ISNULL([source].[last_access], [target].[last_access])
			,[target].[last_server_restart] = [source].[last_server_restart]
			,[target].[last_audit_datetime] = GETDATE()
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT VALUES ([source].[name]
			,ISNULL([source].[last_access], [source].[last_server_restart])
			,[source].[last_server_restart]
			,GETDATE()
			,GETDATE())
	WHEN NOT MATCHED BY SOURCE AND DATEDIFF(DAY, [target].[last_audit_datetime], GETDATE()) > 7 THEN
	DELETE;
END
