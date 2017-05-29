/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[chart_capacity_db]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @file_info AS TABLE([database_id] INT,
		[file_id] INT,
		[data_type] CHAR(4),
		[drive] CHAR(1),
		[size_used_mb] NUMERIC(20,2),
		[size_reserved_mb] NUMERIC(20,2));

	INSERT INTO @file_info
	EXEC [system].[execute_foreach_db] 'USE [?];
		SELECT DB_ID() AS [database_id]
			,[F].[file_id]
			,CASE WHEN [F].[type_desc] = N''LOG'' THEN ''log'' ELSE ''data'' END AS [data_type]
			,SUBSTRING([F].[physical_name],1,1) AS [drive]
			,CAST(ISNULL(fileproperty([F].[name],''SpaceUsed''),0)/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
			,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
		FROM [sys].[database_files] [F];';

	INSERT INTO @file_info
	SELECT [F].[database_id]
		,[F].[file_id]
		,CASE WHEN [F].[type_desc] = N'LOG' THEN 'log' ELSE 'data' END AS [data_type]
		,SUBSTRING([F].[physical_name],1,1) AS [drive]
		,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
		,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
	FROM [sys].[master_files] [F]
	WHERE [F].[database_id] NOT IN (SELECT [database_id] FROM @file_info);

	SELECT DB_NAME([P1].[database_id]) AS [data_space]
		,[P1].[rows_size_used_mb] + [P1].[log_size_used_mb] AS [used]
		,[P2].[rows_size_reserved_mb] + [P2].[log_size_reserved_mb] AS [reserved]
		,NULL AS [max]
		,NULL AS [used_warning]
		,NULL AS [used_critical]
		,'MB' AS [unit]
	FROM
	(SELECT [database_id],
		[P].[log] AS [log_size_used_mb], 
		[P].[data] AS [rows_size_used_mb]
	FROM
	(
	SELECT [database_id],
		CASE WHEN [data_type] = N'LOG' THEN 'log' ELSE 'data' END AS [data_type],
		[size_used_mb]
	FROM @file_info
	) AS [S]
	PIVOT
	(
	SUM([S].[size_used_mb])
	FOR [S].[data_type] IN ([log], [data])
	) AS [P]) [P1]
	INNER JOIN 
	(SELECT [database_id],
		[P].[log] AS [log_size_reserved_mb], 
		[P].[data] AS [rows_size_reserved_mb]
	FROM
	(
	SELECT [database_id],
		CASE WHEN [data_type] = N'LOG' THEN 'log' ELSE 'data' END AS [data_type],
		[size_reserved_mb]
	FROM @file_info
	) AS [S]
	PIVOT
	(
	SUM([S].[size_reserved_mb])
	FOR [S].[data_type] IN ([log], [data])
	) AS [P]) [P2]
	ON [P1].[database_id] = [P2].[database_id];
END