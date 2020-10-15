/*



*/

CREATE PROCEDURE [health].[get_statistic_state]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @stats TABLE (
		[db_name] sysname,
		[object_name] sysname,
		[stat_name] sysname,
		[last_update] DATETIME2,
		[rows] BIGINT,
		[rows_sampled] BIGINT,
		[modification_counter] BIGINT,
		[percent_sample] NUMERIC(5,2),
		[percent_change] NUMERIC(18,2)
	);

	INSERT INTO @stats
	EXEC [system].[execute_foreach_db] N'USE [?]; 
		SELECT [db_name] = DB_NAME()
			,[object_name] = OBJECT_NAME([s].[object_id])
			,[stat_name] = [s].[name]
			,[sp].[last_updated]
			,[sp].[rows] 
			,[sp].[rows_sampled]
			,[sp].[modification_counter]
			,[percent_sample] = CASE [sp].[rows_sampled] WHEN 0 THEN 0 ELSE CAST(100.00 * [sp].[rows_sampled]/[sp].[rows] AS NUMERIC(5,2)) END
			,[percent_change] = CASE [sp].[modification_counter] WHEN 0 THEN 0 ELSE CAST(100.00 * [sp].[modification_counter]/[sp].[rows] AS NUMERIC(18,2)) END
		FROM sys.objects [o]
			INNER JOIN sys.indexes [i]
				ON [o].[object_id] = [i].[object_id]
			INNER JOIN (SELECT [object_id], [index_id], [row_count]=SUM([row_count]) FROM sys.dm_db_partition_stats GROUP BY [object_id], [index_id]) [ps]
				ON [o].[object_id] = [ps].[object_id]
					AND [i].[index_id] = [ps].[index_id]
			INNER JOIN sys.stats [s]
				ON [o].[object_id] = [s].[object_id]
					AND [i].[index_id] = [s].[stats_id]
			CROSS APPLY sys.dm_db_stats_properties([s].[object_id], [s].[stats_id]) [sp]
		WHERE [o].[type] = ''U''
			AND [ps].[row_count] > 1'

	SELECT * FROM @stats;
END
