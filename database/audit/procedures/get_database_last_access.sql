CREATE PROCEDURE [audit].[get_database_last_access]
WITH ENCRYPTION
AS
BEGIN
	DECLARE @objects TABLE ([db_id] INT, [object_id] INT, [object_name] VARCHAR(128));
	DECLARE @last_access TABLE ([db_name] [nvarchar](128) NOT NULL
								,[db_last_access] [datetime] NULL
								,[server_last_restart] [datetime] NOT NULL
								,[report_datatime] [datetime] NOT NULL);

	INSERT INTO @objects
		EXEC [system].[execute_foreach_db] N'SELECT DB_ID(''?'') AS [db_id], [object_id], [name] FROM [?].sys.objects WHERE [is_ms_shipped] = 0 AND [type] = ''U'';';

	INSERT INTO @last_access
		SELECT [db_name]
			,MAX(CASE WHEN [db_last_access] = '19000101' THEN NULL ELSE [db_last_access] END) AS [db_last_access]
			,[server_last_restart]
			,GETDATE() AS [report_datetime]
		FROM
		(SELECT [D].[name] AS [db_name],
			ISNULL([X].[last_user_seek],'19000101') AS [last_user_seek],
			ISNULL([X].[last_user_scan],'19000101') AS [last_user_scan],
			ISNULL([X].[last_user_lookup],'19000101') AS [last_user_lookup],
			ISNULL([X].[last_user_update],'19000101') AS [last_user_update],
			(SELECT [create_date] FROM sys.databases WHERE [name] = 'tempdb') AS [server_last_restart]
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
		,[server_last_restart];

	MERGE [audit].[database_last_access] AS [target]
	USING (
	SELECT [db_name]
		,[db_last_access]
		,[server_last_restart]
		,[report_datatime]
	FROM @last_access
	) AS [source]
	ON ([target].[db_name] = [source].[db_name]) 
	WHEN MATCHED THEN
		UPDATE SET [target].[db_last_access] = ISNULL([source].[db_last_access], [target].[db_last_access])
			,[target].[server_last_restart] = [source].[server_last_restart]
			,[target].[report_datatime] = [source].[report_datatime]
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT VALUES ([source].[db_name]
			,ISNULL([source].[db_last_access], [source].[server_last_restart])
			,[source].[server_last_restart]
			,[source].[report_datatime])
	WHEN NOT MATCHED BY SOURCE AND DATEDIFF(DAY, [target].[report_datatime], GETDATE()) > 7 THEN
	DELETE;
END
