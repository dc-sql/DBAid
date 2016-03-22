/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[capacity]
WITH ENCRYPTION
AS

BEGIN
	SET NOCOUNT ON;

	DECLARE @check_date CHAR(29);

	DECLARE @fixeddrives TABLE([drive] CHAR(1),
							[free_mb] NUMERIC(20,2));
	
	DECLARE @drive_info TABLE([drive] CHAR(1),
							[capacity_mb] NUMERIC(20,2),
							[free_mb] NUMERIC(20,2));

	DECLARE @file_info AS TABLE([database_name] NVARCHAR(128),
		[filegroup_name] NVARCHAR(128),
		[filegroup_is_readonly] BIT,
		[drive] CHAR(1),
		[file_name] NVARCHAR(128),
		[file_type] NVARCHAR(4),
		[used_mb] NUMERIC(20,2),
		[reserved_mb] NUMERIC(20,2));

	SELECT @check_date=[date1] FROM [dbo].[string_date_with_offset](GETDATE(), NULL);
	
	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	INSERT INTO @fixeddrives
		EXEC(N'EXEC xp_fixeddrives');
  
	INSERT INTO @drive_info
		SELECT [disk].[drive]
			,CAST(ROUND(CAST([value] AS BIGINT) / 1048576.00, 2) AS NUMERIC(20,2)) AS [capacity_mb]
			,[F].[free_mb]
		FROM [dbo].[service] [S]
			CROSS APPLY (SELECT SUBSTRING([S].[hierarchy], CHARINDEX('Win32_Volume/', [S].[hierarchy]) + 13, 1) AS [drive]) [disk]
			INNER JOIN @fixeddrives [F]
				ON [disk].[drive] = [F].[drive]
		WHERE [property] = N'Capacity'
		AND [hierarchy] LIKE N'%Win32_Volume%'

		INSERT INTO @file_info
			EXEC [dbo].[foreachdb] 'USE [?]; 
				SELECT DB_NAME() AS [database_name]
					,[FG].[name] AS [filegroup_name]
					,[FG].[is_read_only]
					,SUBSTRING([M].[physical_name],1,1) AS [drive]
					,[M].[name] AS [file_name]
					,[M].[type_desc] AS [file_type]
					,CAST(ISNULL(fileproperty([M].[name],''SpaceUsed''),0)/128.00 AS NUMERIC(20,2)) AS [used_mb]
					,CAST([M].[size]/128.00 AS NUMERIC(20,2)) AS [reserved_mb]
				FROM [sys].[database_files] [M]
					LEFT JOIN [sys].[filegroups] [FG]
						ON [M].[data_space_id] = [FG].[data_space_id]
				WHERE [M].[type] IN (0,1)'; 

	REVERT;
	REVERT;

	SELECT 
		(SELECT [guid] FROM [dbo].[instanceguid]()) AS [instance_guid],
		[DI].[database_name],
		[MF].[physical_name],
		[MF].[name] AS [logical_name],
		[MF].[type_desc],
		[DI].[used_mb],
		[DI].[reserved_mb],
		[DR].[drive],
		[DR].[free_mb],
		[DR].[capacity_mb],
		@check_date AS [check_date]
	FROM [master].[sys].[master_files] [MF]
		INNER JOIN @file_info [DI] 
			ON DB_ID([DI].database_name) = [MF].database_id AND [DI].[file_type] = [MF].[type_desc] Collate Database_Default AND [DI].[file_name] = [MF].[name]
		INNER JOIN @drive_info [DR] 
			ON [DR].[drive] = [DI].[drive] Collate Database_Default

END