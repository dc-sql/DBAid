SET NOCOUNT ON;

DECLARE @drive_info AS TABLE(
	[database_id] INT,
	[data_type] VARCHAR(4),
	[volume_mount_point] NVARCHAR(512),
	[volume_total_mb] NUMERIC(20,2),
	[volume_available_mb] NUMERIC(20,2)
);

DECLARE @file_info AS TABLE(
	[database_id] INT,
	[data_type] VARCHAR(4),
	[size_used_mb] NUMERIC(20,2),
	[size_reserved_mb] NUMERIC(20,2));

/* Sometimes dm_os_volume_stats doesn't return disk volume information due to wonky permissions in the OS. */
INSERT INTO @drive_info
	SELECT [mf].[database_id],
		[data_type] = CASE WHEN [mf].[type_desc] = N'LOG' THEN 'log' ELSE 'data' END,
		[vs].[volume_mount_point],
		[volume_total_mb] = CAST([vs].[total_bytes] / 1024.00 / 1024 AS NUMERIC(20,2)),
		[volume_available_mb] = CAST([vs].[available_bytes] / 1024.00 / 1024 AS NUMERIC(20,2))
	FROM sys.master_files [mf]
		CROSS APPLY sys.dm_os_volume_stats ([mf].[database_id], [mf].[file_id]) [vs]
	GROUP BY [mf].[database_id],
		[mf].[type_desc],
		[vs].[volume_mount_point],
		[vs].[total_bytes],
		[vs].[available_bytes]

INSERT INTO @file_info
	EXEC [system].[execute_foreach_db] 'USE [?];
		SELECT DB_ID() AS [database_id]
			,CASE WHEN [F].[type_desc] = N''LOG'' THEN ''log'' ELSE ''data'' END AS [data_type]
			,CAST(ISNULL(fileproperty([F].[name],''SpaceUsed''),0)/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
			,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
		FROM [sys].[database_files] [F];';

INSERT INTO @file_info
	SELECT [F].[database_id]
		,CASE WHEN [F].[type_desc] = N'LOG' THEN 'log' ELSE 'data' END AS [data_type]
		,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
		,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
	FROM [sys].[master_files] [F]
	WHERE [F].[database_id] NOT IN (SELECT [database_id] FROM @file_info);

SELECT REPLACE(DB_NAME([d].[database_id]) + '_' + REPLACE(REPLACE([d].[volume_mount_point],':',''),'\','_') + '_' + [d].[data_type],'__','_') AS [name]
	,SUM([f].[size_used_mb]) AS [used]
	,SUM([f].[size_reserved_mb]) AS [reserved]
	,[d].[volume_available_mb] AS [max]
	,'MB' AS [uom]
FROM @drive_info [d]
	INNER JOIN @file_info [f]
		ON [d].[database_id] = [f].[database_id]
			AND [d].[data_type] = [f].[data_type]
GROUP BY [d].[database_id], 
	[d].[volume_mount_point],
	[d].[volume_available_mb],
	[d].[data_type]
ORDER BY DB_NAME([d].[database_id])
	,[d].[data_type]