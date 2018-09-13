/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_database_file]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'DATABASE' as [heading], 'Files' as [subheading], 'This is a list of databases files' as [comment]

	SELECT DB_NAME([F].[database_id]) AS [database_name]
		,[F].[name] AS [file_name]
		,[F].[type_desc]
		,[F].[state_desc]
		,[F].[physical_name]
		,CAST([F].[size]/128.00 AS NUMERIC(20,2)) AS [allocated_size_mb]
		,CASE 
			WHEN [F].[max_size] < 0 THEN 'Unlimited' 
			WHEN [F].[max_size] = 0 OR [F].[growth] = 0 THEN 'No Growth Allowed'
			ELSE CAST(CAST([F].[max_size]/128.00 AS NUMERIC(20,2)) AS VARCHAR(22)) + 'MB'
		END AS [max_size_mb]
		,CASE [F].[is_percent_growth] 
			WHEN 0 THEN 
				CASE 
					WHEN [F].[growth] = 0 THEN NULL 
					ELSE CAST(CAST([F].[growth]/128.00 AS NUMERIC(20,2)) AS VARCHAR(22)) + 'MB' 
				END
			WHEN 1 THEN 
				CASE
					WHEN [F].[growth] = 0 THEN NULL 
					ELSE CAST([F].[growth] AS VARCHAR(3)) + '%'
				END
		END AS [auto_grow]
		,[F].[is_read_only]
	FROM [master].[sys].[master_files] [F] 
		INNER JOIN [master].[sys].[databases] [D] 
			ON [F].[database_id] = [D].[database_id]
END
