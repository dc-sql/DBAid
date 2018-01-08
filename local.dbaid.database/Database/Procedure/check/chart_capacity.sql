/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [chart].[capacity] 
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @cmd NVARCHAR(1000);

	DECLARE @drive_info AS TABLE([drive] CHAR(1),
								[mb_free] NUMERIC(20,2));

	DECLARE @file_info AS TABLE([database_id] INT,
								[filegroup_id] INT,
								[filegroup_name] NVARCHAR(128),
								[filegroup_is_readonly] BIT,
								[file_id] INT,
								[file_type] NVARCHAR(4),
								[drive] CHAR(1),
								[size_used_mb] NUMERIC(20,2),
								[size_reserved_mb] NUMERIC(20,2));

	DECLARE @space_info AS TABLE([database_id] INT,
								[file_id] INT,
								[size_available_mb] NUMERIC(20,2),
								[disk_available_mb] NUMERIC(20,2),
								[max_size] INT,
								[growth] INT,
								[is_percent_growth] INT);
	
	-- Sometimes dm_os_volume_stats doesn't return disk volume information due to wonky permissions in the OS. Using xp_fixeddrives for now.
	/* IF EXISTS (SELECT * FROM sys.system_objects WHERE [name] = N'dm_os_volume_stats')
	BEGIN
		SET @cmd = N'SELECT DISTINCT SUBSTRING([V].[volume_mount_point],1,1) AS [drive]
						,CAST([V].[available_bytes]/1024.00/1024.00 AS NUMERIC(20,2)) AS [available_mb] 
					 FROM sys.master_files [F]
					  CROSS APPLY sys.dm_os_volume_stats([F].[database_id], [F].[file_id]) [V]';
	END
	ELSE
	BEGIN */
	SET @cmd = N'EXEC xp_fixeddrives';
	--END

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	INSERT INTO @drive_info
		EXEC(@cmd);

	INSERT INTO @file_info
		EXEC [dbo].[foreachdb] 'USE [?]; 
			SELECT DB_ID() AS [database_id]
				,ISNULL([FG].[data_space_id],0)
				,[FG].[name]
				,[FG].[is_read_only]
				,[M].[file_id]
				,[M].[type_desc]
				,SUBSTRING([M].[physical_name],1,1) AS [drive]
				,CAST(ISNULL(fileproperty([M].[name],''SpaceUsed''),0)/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
				,CAST([M].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
			FROM [sys].[database_files] [M]
				LEFT JOIN [sys].[filegroups] [FG]
					ON [M].[data_space_id] = [FG].[data_space_id]
			WHERE [M].[type] IN (0,1)'; 

	INSERT INTO @file_info
		SELECT [F].[database_id]
			,NULL AS [filegroup_id]
			,NULL AS [filegroup_name]
			,NULL AS [filegroup_is_readonly]
			,[F].[file_id]
			,[F].[type_desc]
			,SUBSTRING([F].[physical_name],1,1) AS [drive]
			,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
			,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
		FROM [dbo].[config_database] [C]
			INNER JOIN [sys].[master_files] [F]
				ON [C].[database_id] = [F].[database_id]
		WHERE [F].[database_id] NOT IN (SELECT [database_id] FROM @file_info)
			AND [F].[type] IN (0,1);

	INSERT INTO @space_info
		SELECT [DB].[database_id]
			,[MF].[file_id]
			,CAST(CASE
				WHEN [FI].[filegroup_is_readonly] = 1 /* When file group is read-only */
					THEN [FI].[size_reserved_mb]-[FI].[size_used_mb] 
				WHEN [MF].[max_size] = -1 /* When max growth file size is unlimited */
					THEN 
					CASE 
						WHEN [MF].[growth] = 0 /* When file growth is disabled */
							THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
						WHEN [MF].[growth] > 0 /* When file growth is enabled */
							THEN 
								CASE 
									WHEN [MF].[is_percent_growth] = 0 /* When file growth is megabyte */
										THEN 
											CASE 
												WHEN ([MF].[growth]/128.00) > [C].[mb_free] /* When file growth is greater than AvailableFreeSpaceMB */
													THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
												WHEN ([MF].[growth]/128.00) <= [C].[mb_free]
													THEN [C].[mb_free]
											END
									WHEN [MF].[is_percent_growth] = 1 /* When file growth is percent */
										THEN
											CASE
												WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) > [C].[mb_free] /* When file growth is greater than AvailableFreeSpaceMB */
													THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
												WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) <= [C].[mb_free]
													THEN [C].[mb_free]
											END
								END
					END
				WHEN [MF].[max_size] > 0
					THEN 
					CASE 
						WHEN [MF].[growth] = 0 /* When file growth is disabled */
							THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
						WHEN [MF].[growth] > 0 /* When file growth is enabled */
							THEN 
							CASE
								WHEN [MF].[is_percent_growth] = 0 
									THEN 
										CASE 
											--WHEN ([MF].[max_size]/128.00) > [C].[mb_free] /* When maximum file size is greater than AvailableFreeSpaceMB */  --this seems weird
											  WHEN (([MF].[max_size]/128.00) - [FI].[size_reserved_mb]) > [C].[mb_free]
												THEN /* Then calculate using disk AvailableFreeSpaceMB */
													CASE
														WHEN ([MF].[growth]/128.00) > [C].[mb_free] /* When file growth is greater than disk AvailableFreeSpaceMB */
															THEN [FI].[size_reserved_mb]-[FI].[size_used_mb] /* Then calculate available space from file reserved space minus used space */
														WHEN ([MF].[growth]/128.00) <= [C].[mb_free] /* When file growth is less than equal to disk AvailableFreeSpaceMB */
															THEN [C].[mb_free] /* Then return disk AvailableFreeSpaceMB */
													END
											--WHEN ([MF].[max_size]/128.00) < [C].[mb_free] /* When maximum file size is less than disk AvailableFreeSpaceMB */
											 WHEN (([MF].[max_size]/128.00) - [FI].[size_reserved_mb]) < [C].[mb_free]
												THEN /* Then calculate using maximum file size */
													CASE
														WHEN ([MF].[growth]/128.00) > (([MF].[max_size]/128.00)-([MF].[size]/128.00)) /* When file growth is greater than file max size */
															THEN [FI].[size_reserved_mb]-[FI].[size_used_mb] /* Then calculate available space from file reserved space minus used space*/
														WHEN ([MF].[growth]/128.00) <= (([MF].[max_size]/128.00)-([MF].[size]/128.00)) /* When file growth is less than equal to file max size */
															THEN ([MF].[max_size]/128.00)-[FI].[size_used_mb] /* Then calculate available space from max file size minus used space*/
													END
										END
										
								WHEN [MF].[is_percent_growth] = 1 
									THEN 
										CASE 
											--WHEN ([MF].[max_size]/128.00) > [C].[mb_free]
											  WHEN (([MF].[max_size]/128.00) - [FI].[size_reserved_mb]) > [C].[mb_free]
												THEN
													CASE
														WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) > [C].[mb_free]
															THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
														WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) < [C].[mb_free]
															THEN [C].[mb_free]
													END
											--WHEN ([MF].[max_size]/128.00) < [C].[mb_free]
											WHEN (([MF].[max_size]/128.00) - [FI].[size_reserved_mb]) < [C].[mb_free]
												THEN
													CASE
														WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) >= (([MF].[max_size]/128.00)-([MF].[size]/128.00))
															THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
														WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) < (([MF].[max_size]/128.00)-([MF].[size]/128.00))
															THEN ([MF].[max_size]/128.00)-[FI].[size_used_mb]
													END
										END
							END
					END
			END  AS NUMERIC(20,2)) AS [size_available_mb]
			,CAST([C].[mb_free] AS NUMERIC(20,2)) AS [disk_available_mb]
			,CASE
				WHEN 
					[MF].[max_size] = -1 AND [MF].[growth] = 0 THEN [FI].[size_reserved_mb]
				ELSE
					[MF].[max_size]
				END AS [max_size]
			,[MF].[growth]
			,[MF].[is_percent_growth]
		FROM sys.databases [DB]
			INNER JOIN sys.master_files [MF]
				ON [DB].[database_id] = [MF].[database_id]
			INNER JOIN @file_info [FI]
				ON [DB].[database_id] = [FI].[database_id]
					AND [MF].[file_id] = [FI].[file_id]
			INNER JOIN @drive_info [C]
				ON SUBSTRING([MF].[physical_name],1,1) = [C].[drive] COLLATE Database_Default;

	;WITH Dataset
	AS
	(
		SELECT [C].[database_id]
			,[C].[db_name]
			,CASE WHEN [F].[filegroup_name] IS NULL THEN [F].[file_type]
				ELSE [F].[file_type] + '_' + [F].[filegroup_name]
				END AS [data_space]
			,SUM([F].[size_used_mb]) AS [used]
			,CASE WHEN [F].[filegroup_is_readonly] = 1 OR [DB].[is_read_only] = 1 OR [DB].[state] != 0 THEN NULL 
				ELSE (SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb]))-((SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb])) * (CAST([C].[capacity_warning_percent_free] AS NUMERIC(5,2))/100.00))
				END AS [warning]
			,CASE WHEN [F].[filegroup_is_readonly] = 1 OR [DB].[is_read_only] = 1 OR [DB].[state] != 0 THEN NULL 
				ELSE (SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb]))-((SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb])) * (CAST([C].[capacity_critical_percent_free] AS NUMERIC(5,2))/100.00))
				END AS [critical]
			,SUM([F].[size_reserved_mb]) AS [reserved]
			,CASE WHEN [F].[filegroup_is_readonly] = 1 OR [DB].[is_read_only] = 1 THEN SUM([F].[size_reserved_mb])
				ELSE (SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb]))
				END AS [max]
			,MAX([S].[fg_size_available_mb]) AS [fg_size_available_mb]
		FROM [dbo].[config_database] [C]
			INNER JOIN [sys].[databases] [DB]
				ON [C].[database_id] = [DB].[database_id] AND [C].[is_enabled] = 1
			INNER JOIN @file_info [F]
				ON [C].[database_id] = [F].[database_id]
			CROSS APPLY (SELECT SUM([A].[fg_size_available_mb]) AS [fg_size_available_mb]
						FROM (SELECT CASE WHEN 
											--SUM([SI].[size_available_mb]) >= MAX([SI].[disk_available_mb])
											(SUM([SI].[max_size]/128.00)-SUM([FI].[size_reserved_mb])) >= MAX([SI].[disk_available_mb]) --When the potential max size of the database if greater than the disk free
												 OR (SUM([SI].[growth]) > 0 ) AND (MIN([SI].[max_size]) < 0) --Or check if growth is unlimited.
											THEN MAX([SI].[disk_available_mb]) + (SUM([FI].[size_reserved_mb])-SUM([FI].[size_used_mb]))
											--THEN SUM([SI].[size_available_mb]) 
											ELSE SUM([SI].[size_available_mb]) 
											END AS [fg_size_available_mb]
								FROM @space_info [SI]
									INNER JOIN @file_info [FI]
										ON [SI].[database_id] = [FI].[database_id]
											AND [SI].[file_id] = [FI].[file_id]
								WHERE [FI].[database_id] = [F].[database_id]
									AND ([FI].[filegroup_id] = [F].[filegroup_id] OR ([FI].[filegroup_id] IS NULL AND [FI].[file_type] = [F].[file_type]))
								GROUP BY [FI].[database_id]
									,[FI].[filegroup_id]
									,[FI].[file_type]
									,[FI].[drive]
									) [A]) [S]([fg_size_available_mb])
		GROUP BY [C].[database_id]
			,[C].[db_name]
			,[DB].[is_read_only]
			,[DB].[state]
			,[F].[filegroup_name]
			,[F].[filegroup_is_readonly]
			,[F].[file_type]
			,[C].[capacity_critical_percent_free]
			,[C].[capacity_warning_percent_free]
	)
	SELECT	
		CAST([used] AS NUMERIC(20,2)) AS [val]
		,CASE WHEN CAST([warning] AS NUMERIC(20,2)) < 1 THEN NULL ELSE CAST([warning] AS NUMERIC(20,2)) END AS [warn]
		,CASE WHEN CAST([critical] AS NUMERIC(20,2)) < 1 THEN NULL ELSE CAST([critical] AS NUMERIC(20,2)) END AS [crit]
		,N''''
		+ REPLACE([db_name],N' ',N'_')
		+ N'_'
		+ REPLACE([data_space],N' ',N'_')
		+ N'_used''='
		+ CAST([used] AS VARCHAR(20))
		+ N';'
		+ ISNULL(CAST([warning] AS VARCHAR(20)),'')
		+ N';'
		+ ISNULL(CAST([critical] AS VARCHAR(20)),'')
		+ N';0;'
		+ CAST([max] AS VARCHAR(20))
		+ N'|'''
		+ REPLACE([db_name],N' ',N'_')
		+ N'_'
		+ REPLACE([data_space],N' ',N'_')
		+ N'_reserved''='
		+ CAST([reserved] AS VARCHAR(20))
		+ N';;;;' AS [pnp]
	FROM Dataset
	ORDER BY [database_id], [data_space];

	REVERT;
END;
