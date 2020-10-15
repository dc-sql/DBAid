/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [health].[get_file_io_performance]
WITH ENCRYPTION
AS
BEGIN
;WITH [dm_io_virtual_file_stats]
AS
(
    SELECT *
    FROM sys.dm_io_virtual_file_stats(NULL, NULL)
)
SELECT [db_name] = DB_NAME ([fs].[database_id])
	,[vs].[volume_mount_point]
	,[mf].[physical_name]
	,[avg_latency_read_ms] = CASE WHEN [num_of_reads] = 0 THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END
	,[avg_latency_write_ms] = CASE WHEN [num_of_writes] = 0 THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END
	,[avg_latency_total_ms] = CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0) THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END
	,[avg_bytes_per_read] = CASE WHEN [num_of_reads] = 0 THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END
	,[avg_bytes_per_write] = CASE WHEN [num_of_writes] = 0 THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END
	,[avg_bytes_total] = CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0) THEN 0 ELSE (([num_of_bytes_read] + [num_of_bytes_written]) / ([num_of_reads] + [num_of_writes])) END
FROM sys.master_files AS [mf]
	CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) [vs]
	INNER JOIN [dm_io_virtual_file_stats] [fs]
		ON [mf].[database_id] = [fs].[database_id]
			AND [mf].[file_id] = [fs].[file_id]
ORDER BY [avg_latency_total_ms] DESC;
END
