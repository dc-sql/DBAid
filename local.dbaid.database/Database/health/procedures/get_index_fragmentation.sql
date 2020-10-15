/*
Returns LIMITED index fragmention stats
and historical index operation information from the Ola [dbo].[CommandLog]
*/

CREATE PROCEDURE [health].[get_index_fragmentation]
WITH ENCRYPTION
AS
BEGIN
	DECLARE @indexes TABLE (
		[dbid] INT,
		[object_id] INT,
		[index_id] INT,
		[partition_number] INT,
		[name] sysname NULL,
		[type] sysname
	);

	INSERT INTO @indexes
	EXEC [system].[execute_foreach_db] N'USE [?]; 
		SELECT [dbid]=DB_ID()
			,[i].[object_id]
			,[i].[index_id]
			,[p].[partition_number]
			,[i].[name]
			,[i].[type_desc] 
		FROM sys.indexes [i]
			INNER JOIN sys.partitions [p] 
				ON [i].[object_id] = [p].[object_id] 
					AND [i].[index_id] = [p].[index_id]';

	;WITH LogData
	AS
	(
		SELECT [dbid] = DB_ID([cl].[DatabaseName])
			,[object_id] = OBJECT_ID([cl].[DatabaseName] + N'.' + [cl].[SchemaName] + N'.' + [cl].[ObjectName])
			,[index_name] = [cl].[IndexName]
			,[index_type] = [cl].[IndexType]
			,[partition_number] = [cl].[PartitionNumber]
			,[operation] = CASE WHEN [cl].[Command] LIKE N'ALTER INDEX % ON % REORGANIZE%' THEN N'REORGANIZE' WHEN [cl].[Command] LIKE N'ALTER INDEX % ON % REBUILD%' THEN N'REBUILD' END
			,[page_count] = [cl].[ExtendedInfo].value('(ExtendedInfo/PageCount)[1]','BIGINT')
			,[fragmentation] = [cl].[ExtendedInfo].value('(ExtendedInfo/Fragmentation)[1]','NUMERIC(8,4)')
		FROM [dbo].[CommandLog] [cl]
		WHERE [cl].[CommandType] = N'ALTER_INDEX'
			AND [cl].[ErrorNumber] = 0
			AND [cl].[StartTime] > DATEADD(MONTH, -1, GETDATE())
	)
	SELECT [db_name] = DB_NAME([i].[dbid])
		,[object_name] = OBJECT_NAME([i].[object_id], [i].[dbid])
		,[i].[name]
		,[i].[type]
		,[i].[partition_number]
		,[current_avg_fragmentation] = AVG([ps].[avg_fragmentation_in_percent])
		,[current_page_count] = MAX([ps].[page_count])
		,[historic_avg_fragmentation] = AVG([ld].[fragmentation])
		,[historic_avg_page_count] = AVG([ld].[page_count])
		,[historic_stdevp_fragmentation] = STDEVP([ld].[fragmentation])
		,[reorg_count_past_month] = SUM(CASE [ld].[operation] WHEN N'REORGANIZE' THEN 1 ELSE 0 END)
		,[rebuild_count_past_month] = SUM(CASE [ld].[operation] WHEN N'REBUILD' THEN 1 ELSE 0 END)
	FROM @indexes [i]
		CROSS APPLY sys.dm_db_index_physical_stats([i].[dbid], [i].[object_id], [i].[index_id], [i].[partition_number], 'LIMITED') [ps]
		LEFT JOIN LogData [ld]
			ON [i].[dbid] = [ld].[dbid]
				AND [i].[object_id] = [ld].[object_id]
				AND [i].[name] = [ld].[index_name]
				AND [i].[partition_number] = [ld].[partition_number]	
	GROUP BY [i].[dbid]
		,[i].[object_id]
		,[i].[name]
		,[i].[type]
		,[i].[partition_number];
END
