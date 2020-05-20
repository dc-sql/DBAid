/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [chart].[capacity_combined]
WITH ENCRYPTION
AS
BEGIN
    /* this procedure only works with Windows running SQL 2012 and above. */

    EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

    SET NOCOUNT ON;

    DECLARE @sql nvarchar(max) = N'',
            @dbname sysname;

    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollofilesizesraw%')
      DROP TABLE #apollofilesizesraw;
    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollofileusedraw%')
      DROP TABLE #apollofileusedraw;
    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollosizesmonitoroutput%')
      DROP TABLE #apollosizesmonitoroutput;
    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollodblist%')
      DROP TABLE #apollodblist;

    CREATE TABLE #apollofilesizesraw ([database_id] int, [file_id] int, [data_space_id] int, [drive] nchar(1), [file_size_kb] decimal(20,2), [drive_size_kb] decimal(20,2));
    CREATE TABLE #apollofileusedraw ([file_used_kb] decimal(20,2), [drive] char(1));
    CREATE TABLE #apollosizesmonitoroutput ([drive] nchar(1), [file_size_total_kb] decimal(20,2), [file_used_total_kb] decimal(20,2), [drive_size_kb] decimal(20,2));
    CREATE TABLE #apollodblist ([database_id] int, [name] sysname);

    -- get list of online databases that we can connect to (i.e. not aag secondary replicas)
    -- could use [sys].[availability_replicas].[is_primary_replica] if SQL 2012 DMV had that column :(
    -- this procedure not really intended to be run against DR replicas; disks should be configured the same as prod anyway.
    -- still, we don't want this procedure to just fail.
    INSERT INTO #apollodblist ([database_id], [name])
      SELECT d.[database_id], d.[name]
      FROM sys.databases d
      WHERE d.[state_desc] = 'ONLINE'
        AND d.[database_id] NOT IN (SELECT rs.[database_id] 
                                    FROM sys.dm_hadr_database_replica_states rs
                                      INNER JOIN sys.availability_replicas ar ON rs.[replica_id] = ar.[replica_id]
                                      INNER JOIN sys.dm_hadr_availability_replica_states ars ON rs.[replica_id] = ars.[replica_id]
                                    WHERE rs.[database_state_desc] = N'ONLINE'
                                      AND ar.[secondary_role_allow_connections_desc] = N'NO'
                                      AND ars.[role_desc] = N'SECONDARY');
                                  
    -- get sizes of all database files
    -- using loop to go through each database as master.sys.master_files doesn't always have correct values,
    --   especially for tempdb (it seems to show sizes tempdb is configured to startup with and doesn't increase when autogrowth occurs).
    DECLARE cursor0 CURSOR FAST_FORWARD FOR
      SELECT [name] FROM #apollodblist;

    OPEN cursor0;

    FETCH cursor0 INTO @dbname;

    WHILE @@FETCH_STATUS = 0
    BEGIN
      SELECT @sql = N'/* get database file sizes */
      ;WITH CTE ([database_id], [file_id], [data_space_id], [drive], [file_size_kb])
      AS
      (
        SELECT DB_ID(' + QUOTENAME(@dbname, '''') + N') AS "database_id", [file_id], [data_space_id], LEFT([physical_name], 1) AS "drive", CONVERT(decimal(20,2), [size]) * 8 AS "file_size_kb"
        FROM ' + QUOTENAME(@dbname) + N'.sys.database_files
      )
      SELECT c.[database_id], c.[file_id], c.[data_space_id], c.[drive], c.[file_size_kb]
      FROM CTE c
        INNER JOIN #apollodblist d ON c.[database_id] = d.[database_id];'
      
      INSERT INTO #apollofilesizesraw ([database_id], [file_id], [data_space_id], [drive], [file_size_kb])
        EXEC sp_executesql @sql;

      FETCH cursor0 INTO @dbname;
    END

    CLOSE cursor0;
    DEALLOCATE cursor0;
    
    -- total combined file sizes per drive
    INSERT INTO #apollosizesmonitoroutput ([drive], [file_size_total_kb])
      SELECT [drive], SUM(file_size_kb) AS "file_sizes" FROM #apollofilesizesraw GROUP BY [drive] ORDER BY [drive];

    -- get size of each drive used by SQL data files
    -- only need to find one db file per drive in order to call sys.dm_os_volume_stats to get drive size
    ;WITH CTE ([rownum], [database_id], [file_id], [drive])
    AS
    (
      SELECT ROW_NUMBER() OVER (PARTITION BY [drive] ORDER BY [database_id], [file_id]) AS "rownum", [database_id], [file_id], [drive]
      FROM #apollofilesizesraw
    )
    UPDATE #apollosizesmonitoroutput
    SET [drive_size_kb] = CAST(dovs.[total_bytes]/1024.0 AS decimal(20,2))
    FROM CTE 
      CROSS APPLY sys.dm_os_volume_stats([database_id], [file_id]) dovs
      INNER JOIN #apollosizesmonitoroutput ao ON ao.[drive] = CTE.[drive]
    WHERE [rownum] = 1;

    -- For each database, get space used per database file
    -- Exclude Always On Availability Group non-readable secondary replicas (can't connect to them)
    DECLARE cursor1 CURSOR FAST_FORWARD FOR
      SELECT [name] FROM #apollodblist;

    OPEN cursor1;

    FETCH cursor1 INTO @dbname;

    WHILE @@FETCH_STATUS = 0
    BEGIN
      SELECT @sql = N'/* get transaction log space used */
      SELECT lsu.[used_log_space_in_bytes] / 1024.0 AS "file_used_kb", LEFT(mf.[physical_name], 1) AS "drive"
      FROM ' + QUOTENAME(@dbname) + N'.sys.dm_db_log_space_usage lsu
        INNER JOIN sys.master_files mf ON lsu.[database_id] = mf.[database_id] AND mf.[type_desc] = ''LOG'';';

      INSERT INTO #apollofileusedraw 
        EXEC sp_executesql @sql;

      SELECT @sql = N'/* get data file space used */
      SELECT fsu.[allocated_extent_page_count] * 8 AS "file_used_kb", LEFT(mf.[physical_name], 1) AS "drive"
      FROM ' + QUOTENAME(@dbname) + N'.sys.dm_db_file_space_usage fsu
        INNER JOIN sys.master_files mf ON fsu.[database_id] = mf.[database_id] AND fsu.[file_id] = mf.[file_id];';

      INSERT INTO #apollofileusedraw 
        EXEC sp_executesql @sql;

      FETCH cursor1 INTO @dbname;
    END

    CLOSE cursor1;
    DEALLOCATE cursor1;

    -- get combined total of space used within data files per drive
    ;WITH CTE AS
    (
      SELECT [drive], SUM([file_used_kb]) AS "file_used_total_kb"
      FROM #apollofileusedraw
      GROUP BY [drive]
    )
    UPDATE #apollosizesmonitoroutput
    SET [file_used_total_kb] = CTE.[file_used_total_kb]
    FROM CTE
      INNER JOIN #apollosizesmonitoroutput ao ON ao.[drive] = CTE.[drive];

    -- format for dbaid.checkmk.exe plugin to understand
    -- "value" = combined file space used, "warning" = combined file sizes, "critical" = drive size, "max" = combined drive size + 5% to force PNP4Nagios to display critical value
    SELECT [file_used_total_kb] AS "val",
           [file_size_total_kb] AS "warn",
           [drive_size_kb] AS "crit",
           QUOTENAME([drive], '''') + N'=' + CAST([file_used_total_kb] AS nvarchar(20)) + N';' + CAST([file_size_total_kb] AS nvarchar(20)) + N';' + CAST([drive_size_kb] AS nvarchar(20)) + N';0;' + CAST(CAST([drive_size_kb]*1.05 AS decimal(20,2)) AS nvarchar(20)) AS "pnp" 
    FROM #apollosizesmonitoroutput;


    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollofilesizesraw%')
      DROP TABLE #apollofilesizesraw;
    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollofileusedraw%')
      DROP TABLE #apollofileusedraw;
    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollosizesmonitoroutput%')
      DROP TABLE #apollosizesmonitoroutput;
    IF EXISTS (SELECT TABLE_NAME FROM tempdb.INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE N'#apollodblist%')
      DROP TABLE #apollodblist;

    REVERT;
END
GO
