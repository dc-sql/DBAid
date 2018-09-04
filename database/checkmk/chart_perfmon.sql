/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[chart_perfmon]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sample1 TABLE ([rownum] BIGINT
							,[object_name] VARCHAR(128)
							,[counter_name] VARCHAR(128)
							,[instance_name] VARCHAR(128)
							,[cntr_value] BIGINT
							,[cntr_type] INT
							,[ms_ticks] BIGINT);

	DECLARE @sample2 TABLE ([rownum] BIGINT
							,[object_name] VARCHAR(128)
							,[counter_name] VARCHAR(128)
							,[instance_name] VARCHAR(128)
							,[cntr_value] BIGINT
							,[cntr_type] INT
							,[ms_ticks] BIGINT);

	INSERT INTO @sample1
		SELECT ROW_NUMBER() OVER (ORDER BY [S].[object_name],[S].[cntr_type],[S].[counter_name],[S].[instance_name]) AS [rownum]
			,RTRIM([S].[object_name])
			,RTRIM([S].[counter_name])
			,RTRIM([S].[instance_name])
			,[S].[cntr_value]
			,[S].[cntr_type]
			,[T].[ms_ticks]
		FROM [sys].[dm_os_performance_counters] [S]
			INNER JOIN [checkmk].[config_perfmon] [C]
				ON RTRIM([S].[object_name]) LIKE [C].[object_name] COLLATE Latin1_General_CI_AS
				AND (RTRIM([S].[counter_name]) LIKE [C].[counter_name] COLLATE Latin1_General_CI_AS 
					OR ISNULL([C].[counter_name],'') = '')
				AND (RTRIM([S].[instance_name]) LIKE [C].[instance_name] COLLATE Latin1_General_CI_AS 
					OR ISNULL([C].[instance_name],'') = '')
			CROSS APPLY (SELECT [ms_ticks] FROM [sys].[dm_os_sys_info]) [T](ms_ticks)

	WAITFOR DELAY '00:00:01';

	INSERT INTO @sample2
		SELECT ROW_NUMBER() OVER (ORDER BY [S].[object_name],[S].[cntr_type],[S].[counter_name],[S].[instance_name]) AS [rownum]
			,RTRIM([S].[object_name])
			,RTRIM([S].[counter_name])
			,RTRIM([S].[instance_name])
			,[S].[cntr_value]
			,[S].[cntr_type]
			,[T].[ms_ticks]
		FROM [sys].[dm_os_performance_counters] [S]
			INNER JOIN [checkmk].[config_perfmon] [C]
				ON RTRIM([S].[object_name]) LIKE [C].[object_name] COLLATE Latin1_General_CI_AS
				AND (RTRIM([S].[counter_name]) LIKE [C].[counter_name] COLLATE Latin1_General_CI_AS 
					OR ISNULL([C].[counter_name],'') = '')
				AND (RTRIM([S].[instance_name]) LIKE [C].[instance_name] COLLATE Latin1_General_CI_AS 
					OR ISNULL([C].[instance_name],'') = '')
			CROSS APPLY (SELECT [ms_ticks] FROM [sys].[dm_os_sys_info]) [T]([ms_ticks]);

	SELECT [S1].[object_name] 
			+ CASE WHEN LEN([S1].[counter_name]) > 0 THEN '_' + [S1].[counter_name] ELSE '' END
			+ CASE WHEN LEN([S1].[instance_name]) > 0 THEN '_' + [S1].[instance_name] ELSE '' END AS [counter_name]
		,[X].[calc_value] AS [val]
		,[C].[check_warning_threshold] AS [val_warn]
		,[C].[check_critical_threshold] AS [val_crit]
		,[U].[uom]
	FROM @sample1 [S1]
		INNER JOIN @sample2 [S2]
			ON [S1].[rownum] = [S2].[rownum]
		INNER JOIN [checkmk].[config_perfmon] [C]
				ON [S1].[object_name] LIKE [C].[object_name] COLLATE Latin1_General_CI_AS
				AND ([S1].[counter_name] LIKE [C].[counter_name] COLLATE Latin1_General_CI_AS 
					OR ISNULL([C].[counter_name],'') = '')
				AND ([S1].[instance_name] LIKE [C].[instance_name] COLLATE Latin1_General_CI_AS 
					OR ISNULL([C].[instance_name],'') = '')
		LEFT JOIN @sample1 [S1BASE]
			ON [S1].[cntr_type] IN (537003264, 1073874176)
				AND [S1BASE].[cntr_type] = 1073939712
				AND [S1].[object_name] = [S1BASE].[object_name]
				AND [S1].[instance_name] = [S1BASE].[instance_name]
				AND [S1].[counter_name] = [S1BASE].[counter_name]
		LEFT JOIN @sample2 [S2BASE]
			ON [S1BASE].[rownum] = [S2BASE].[rownum]
		CROSS APPLY (SELECT CAST(ROUND(CASE WHEN [S1].[cntr_type] = 537003264 THEN	CASE 
										WHEN [S2].[cntr_value] > 0 THEN 100.00 * CAST([S2].[cntr_value] / [S2BASE].[cntr_value] AS NUMERIC(20,2))
										ELSE 0
									END
									WHEN [S1].[cntr_type] = 1073874176 THEN CASE
										WHEN ([S2].[cntr_value] - [S1].[cntr_value]) > 0 THEN ([S2].[cntr_value] - [S1].[cntr_value]) / ([S2BASE].[cntr_value] - [S1BASE].[cntr_value])
										ELSE 0
									END
									WHEN [S1].[cntr_type] = 272696576 THEN CASE
										WHEN ([S2].[cntr_value] - [S1].[cntr_value]) > 0 THEN CAST(([S2].[cntr_value] - [S1].[cntr_value]) AS NUMERIC(20,2)) / (CAST(([S2].[ms_ticks] - [S1].[ms_ticks]) AS NUMERIC(20,2))/1000.00)
										ELSE 0
									END
									WHEN [S1].[cntr_type] = 65792 THEN [S2].[cntr_value]
								END, 2) AS NUMERIC(20,2))) [X]([calc_value])
		CROSS APPLY (SELECT CASE WHEN [S1].[cntr_type] = 537003264 THEN N'%'
								WHEN [S1].[counter_name] LIKE N'%[%]%' THEN N'%'
								WHEN [S1].[cntr_type] = 65792 AND [S1].[counter_name] LIKE N'Percent %' THEN N'%'
								WHEN [S1].[cntr_type] = 65792 AND RTRIM([S1].[counter_name]) = N'Usage' THEN N'c'
								WHEN [S1].[counter_name] LIKE N'%(ms)%' OR [S1].[instance_name] LIKE N'%(ms)%' THEN N'ms'
								WHEN [S1].[counter_name] LIKE N'%(KB)%' OR [S1].[instance_name] LIKE N'%(KB)%' THEN N'KB'
								WHEN [S1].[counter_name] LIKE N'%Bytes%' OR [S1].[instance_name] LIKE N'%Bytes%' THEN N'B'
								ELSE NULL END) [U](uom)
	WHERE [S1].[cntr_type] IN (537003264,1073874176,272696576,65792)
	ORDER BY [S1].[object_name]
			,[S1].[counter_name]
			,[S1].[instance_name];
END
