CREATE PROCEDURE [health].[get_index_fragmentation]
WITH ENCRYPTION
AS
BEGIN
	DECLARE @indexes TABLE (
		[dbid] INT,
		[object_id] INT,
		[index_id] INT,
		[name] sysname NULL,
		[type] sysname
	);

	INSERT INTO @indexes
	EXEC [system].[execute_foreach_db] N'USE [?]; SELECT DB_ID(),[object_id],[index_id],[name],[type_desc] FROM sys.indexes';

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
	SELECT [db_name] = DB_NAME([ld].[dbid])
		,[object_name] = OBJECT_NAME([ld].[object_id], [ld].[dbid])
		,[ld].[index_name]
		,[ld].[index_type]
		,[ld].[partition_number]
		,[current_avg_fragmentation] = AVG([ps].[avg_fragmentation_in_percent])
		,[current_page_count] = MAX([ps].[page_count])
		,[historic_avg_fragmentation] = AVG([ld].[fragmentation])
		,[historic_avg_page_count] = AVG([ld].[page_count])
		,[historic_stdevp_fragmentation] = STDEVP([ld].[fragmentation])
		,[reorg_count_past_month] = SUM(CASE [ld].[operation] WHEN N'REORGANIZE' THEN 1 ELSE 0 END)
		,[rebuild_count_past_month] = SUM(CASE [ld].[operation] WHEN N'REBUILD' THEN 1 ELSE 0 END)
	FROM LogData [ld]
		INNER JOIN @indexes [i]
			ON [ld].[dbid] = [i].[dbid]
				AND [ld].[object_id] = [i].[object_id]
				AND [ld].[index_name] = [i].[name]
		CROSS APPLY sys.dm_db_index_physical_stats([ld].[dbid], [ld].[object_id], [i].[index_id], [ld].[partition_number], 'LIMITED') [ps]	
	GROUP BY [ld].[dbid]
		,[ld].[object_id]
		,[ld].[index_name]
		,[ld].[index_type]
		,[ld].[partition_number];
END
