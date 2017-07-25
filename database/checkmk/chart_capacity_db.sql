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
		[data_type] CHAR(4),
		[size_used_mb] NUMERIC(20,2),
		[size_reserved_mb] NUMERIC(20,2));

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

	SELECT DB_NAME([database_id]) + '_' + [data_type] AS [name]
		,SUM([size_used_mb]) AS [used]
		,SUM([size_reserved_mb]) AS [reserved]
		,'MB' AS [uom]
	FROM @file_info
	GROUP BY [database_id], [data_type]
	ORDER BY DB_NAME([database_id])
		,[data_type]
END