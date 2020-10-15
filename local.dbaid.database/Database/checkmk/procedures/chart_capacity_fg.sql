/*



*/

CREATE PROCEDURE [checkmk].[chart_capacity_fg] 
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @cmd NVARCHAR(1000);

	DECLARE @drive_info AS TABLE([drive] CHAR(1),
								[mb_free] NUMERIC(20,2));

	DECLARE @file_info AS TABLE([database_name] sysname,
								[filegroup_id] INT,
								[filegroup_name] NVARCHAR(128),
								[filegroup_is_readonly] BIT,
								[file_id] INT,
								[file_type] NVARCHAR(4),
								[drive] CHAR(1),
								[size_used_mb] NUMERIC(20,2),
								[size_reserved_mb] NUMERIC(20,2));

	DECLARE @space_info AS TABLE([database_name] sysname,
								[file_id] INT,
								[size_available_mb] NUMERIC(20,2),
								[disk_available_mb] NUMERIC(20,2));

	DECLARE @check_output TABLE([name] NVARCHAR(256),
								[used] NUMERIC(20,2),
								[reserved] NUMERIC(20,2),
								[max] NUMERIC(20,2),
								[warning] NUMERIC(20,2),
								[critical] NUMERIC(20,2),
								[uom] CHAR(2),
								[state] VARCHAR(8), 
								[message] NVARCHAR(4000));

	/* Sometimes dm_os_volume_stats doesn't return disk volume information due to wonky permissions in the OS. Using xp_fixeddrives for now. */
	INSERT INTO @drive_info
		EXEC(N'EXEC xp_fixeddrives');

	INSERT INTO @file_info
		EXEC [system].[execute_foreach_db] 'USE [?]; 
			SELECT DB_NAME() AS [database_name]
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
		SELECT DB_NAME([database_id]) AS [database_name]
			,NULL AS [filegroup_id]
			,NULL AS [filegroup_name]
			,NULL AS [filegroup_is_readonly]
			,[file_id]
			,[type_desc]
			,SUBSTRING([physical_name],1,1) AS [drive]
			,CAST([size]/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
			,CAST([size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
		FROM [sys].[master_files]
		WHERE DB_NAME([database_id]) NOT IN (SELECT [database_name] FROM @file_info)
			AND [type] IN (0,1);

	INSERT INTO @space_info
		SELECT [DB].[name] AS [database_name]
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
												WHEN ([MF].[growth]/128.00) > [DI].[mb_free] /* When file growth is greater than AvailableFreeSpaceMB */
													THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
												WHEN ([MF].[growth]/128.00) <= [DI].[mb_free]
													THEN [DI].[mb_free]
											END
									WHEN [MF].[is_percent_growth] = 1 /* When file growth is percent */
										THEN
											CASE
												WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) > [DI].[mb_free] /* When file growth is greater than AvailableFreeSpaceMB */
													THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
												WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) <= [DI].[mb_free]
													THEN [DI].[mb_free]
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
											WHEN ([MF].[max_size]/128.00) > [DI].[mb_free] /* When maximum file size is greater than AvailableFreeSpaceMB */
												THEN /* Then calculate using disk AvailableFreeSpaceMB */
													CASE
														WHEN ([MF].[growth]/128.00) > [DI].[mb_free] /* When file growth is greater than disk AvailableFreeSpaceMB */
															THEN [FI].[size_reserved_mb]-[FI].[size_used_mb] /* Then calculate available space from file reserved space minus used space */
														WHEN ([MF].[growth]/128.00) <= [DI].[mb_free] /* When file growth is less than equal to disk AvailableFreeSpaceMB */
															THEN [DI].[mb_free] /* Then return disk AvailableFreeSpaceMB */
													END
											WHEN ([MF].[max_size]/128.00) < [DI].[mb_free] /* When maximum file size is less than disk AvailableFreeSpaceMB */
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
											WHEN ([MF].[max_size]/128.00) > [DI].[mb_free]
												THEN
													CASE
														WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) > [DI].[mb_free]
															THEN [FI].[size_reserved_mb]-[FI].[size_used_mb]
														WHEN ([MF].[size]/128.00)*([MF].[growth]/100.00) < [DI].[mb_free]
															THEN [DI].[mb_free]
													END
											WHEN ([MF].[max_size]/128.00) < [DI].[mb_free]
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
			END AS NUMERIC(20,2)) AS [size_available_mb]
			,CAST([DI].[mb_free] AS NUMERIC(20,2)) AS [disk_available_mb]
		FROM sys.databases [DB]
			INNER JOIN sys.master_files [MF]
				ON [DB].[database_id] = [MF].[database_id]
			INNER JOIN @file_info [FI]
				ON [DB].[name] = [FI].[database_name] COLLATE DATABASE_DEFAULT
					AND [MF].[file_id] = [FI].[file_id]
			INNER JOIN @drive_info [DI]
				ON SUBSTRING([MF].[physical_name],1,1) = [DI].[drive] COLLATE DATABASE_DEFAULT;

	;WITH Dataset
	AS
	(
		SELECT [C].[name] AS [database_name]
			,CASE WHEN [F].[filegroup_name] IS NULL THEN [F].[file_type]
				ELSE [F].[file_type] + '_' + [F].[filegroup_name]
				END AS [data_space]
			,SUM([F].[size_used_mb]) AS [used]
			,CASE WHEN [F].[filegroup_is_readonly] = 1 OR [DB].[is_read_only] = 1 OR [DB].[state] != 0 THEN NULL 
				ELSE (SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb]))-((SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb])) * (CAST([C].[capacity_check_warning_free] AS NUMERIC(5,2))/100.00))
				END AS [warning]
			,CASE WHEN [F].[filegroup_is_readonly] = 1 OR [DB].[is_read_only] = 1 OR [DB].[state] != 0 THEN NULL 
				ELSE (SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb]))-((SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb])) * (CAST([C].[capacity_check_critical_free] AS NUMERIC(5,2))/100.00))
				END AS [critical]
			,SUM([F].[size_reserved_mb]) AS [reserved]
			,CASE WHEN [F].[filegroup_is_readonly] = 1 OR [DB].[is_read_only] = 1 THEN SUM([F].[size_reserved_mb])
				ELSE (SUM([F].[size_used_mb]) + MAX([S].[fg_size_available_mb]))
				END AS [max]
		FROM [checkmk].[config_database] [C]
			INNER JOIN [sys].[databases] [DB]
				ON [C].[name] = [DB].[name] COLLATE DATABASE_DEFAULT
			INNER JOIN @file_info [F]
				ON [C].[name] = [F].[database_name]
			CROSS APPLY (SELECT SUM([A].[fg_size_available_mb]) AS [fg_size_available_mb]
						FROM (SELECT CASE WHEN SUM([SI].[size_available_mb]) >= MAX([SI].[disk_available_mb]) 
											THEN MAX([SI].[disk_available_mb]) + (SUM([FI].[size_reserved_mb])-SUM([FI].[size_used_mb]))
											ELSE SUM([SI].[size_available_mb]) END AS [fg_size_available_mb]
								FROM @space_info [SI]
									INNER JOIN @file_info [FI]
										ON [SI].[database_name] = [FI].[database_name]
											AND [SI].[file_id] = [FI].[file_id]
								WHERE [FI].[database_name] = [F].[database_name]
									AND ([FI].[filegroup_id] = [F].[filegroup_id] OR ([FI].[filegroup_id] IS NULL AND [FI].[file_type] = [F].[file_type]))
								GROUP BY [FI].[database_name]
									,[FI].[filegroup_id]
									,[FI].[file_type]
									,[FI].[drive]) [A]) [S]([fg_size_available_mb])
		GROUP BY [C].[name]
			,[DB].[is_read_only]
			,[DB].[state]
			,[F].[filegroup_name]
			,[F].[filegroup_is_readonly]
			,[F].[file_type]
			,[C].[capacity_check_critical_free]
			,[C].[capacity_check_warning_free]
	)
	INSERT INTO @check_output
	SELECT [database_name] + N'_' + [data_space] AS [name]
		,[used]
		,[reserved]
		,[max]
		,[warning]
		,[critical]
		,'MB' AS [uom]
		,[check].[state]
		,[message]=[database_name] 
			+ N'_' 
			+ [data_space] 
			+ N'; used=' 
			+ CAST([used] AS NVARCHAR(10)) 
			+ N'; reserved=' 
			+ CAST([reserved] AS NVARCHAR(10)) 
			+ N'; max=' 
			+ CAST([max] AS NVARCHAR(10))
	FROM Dataset
		CROSS APPLY (SELECT [state]=CASE 
			WHEN [used] < [warning] THEN N'OK' 
			WHEN [used] >= [warning] AND [used] < [critical] THEN N'WARNING' 
			WHEN [used] >= [critical] THEN N'CRITICAL' 
			ELSE N'NA' END) [check]
	ORDER BY [database_name], [data_space];

	SELECT * FROM @check_output;

	IF (@writelog = 1)
	BEGIN
		DECLARE @ErrorMsg NVARCHAR(2048);
		DECLARE ErrorCurse CURSOR FAST_FORWARD FOR 
			SELECT [state] + N' - ' + OBJECT_NAME(@@PROCID) + N' - ' + [message] 
			FROM @check_output 
			WHERE [state] NOT IN ('NA','OK');

		OPEN ErrorCurse;
		FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;

		WHILE (@@FETCH_STATUS=0)
		BEGIN
			EXEC xp_logevent 54321, @ErrorMsg, 'WARNING';  
			FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;
		END

		CLOSE ErrorCurse;
		DEALLOCATE ErrorCurse;
	END
END
