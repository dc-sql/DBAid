/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [health].[get_transaction_log]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @query NVARCHAR(100), @db_name sysname, @MajorVersion TINYINT;
	
	DECLARE @databases TABLE ([db_name] sysname);

	DECLARE @results TABLE (
		[db_name] sysname,
		[file_name] sysname,
		[vlf_count] INT,
		[vlf_in_use] INT,
		[vlf_total_sizeMB] NUMERIC(20,2),
		[vlf_single_largest_sizeMB] NUMERIC(20,2),
		[vlf_stdev_sizeMB] NUMERIC(20,2),
		[tran_oldest_startdate] DATETIME
	);

	DECLARE @dbccloginfo TABLE (
		[fileid] TINYINT,
		[file_size] BIGINT,
		[start_offSET] BIGINT,
		[fseqno] INT,
		[status] TINYINT,
		[parity] TINYINT,
		[create_lsn] NUMERIC(25,0)
	);

	DECLARE @dbccloginfo2012 TABLE (
		[RecoveryUnitId] INT, 
		[fileid] TINYINT,  
		[file_size] BIGINT,  
		[start_offSET] BIGINT,  
		[fseqno] INT,  
		[status] TINYINT,  
		[parity] TINYINT,  
		[create_lsn] NUMERIC(25,0)
	);

	DECLARE @dbccopentran TABLE (
		[key] VARCHAR(25),
		[value] SQL_VARIANT
	);

	SET @MajorVersion = LEFT(CAST(SERVERPROPERTY(N'ProductVersion') AS NVARCHAR(max)),CHARINDEX('.',CAST(SERVERPROPERTY(N'ProductVersion') AS NVARCHAR(max)))-1);
	INSERT INTO @databases SELECT [name] FROM sys.databases WHERE state = 0;

	WHILE EXISTS(SELECT TOP 1 [db_name] FROM @databases)  
	BEGIN  
		SET @db_name = (SELECT TOP 1 [db_name] FROM @databases)  
    
		SET @query = N'DBCC OPENTRAN (' + N'''' + @db_name + N''') WITH TABLERESULTS, NO_INFOMSGS'
		INSERT INTO @dbccopentran EXEC(@query);

		SET @query = N'DBCC LOGINFO (' + N'''' + @db_name + N''') WITH NO_INFOMSGS'  

		IF @MajorVersion < 11
		BEGIN
			INSERT INTO @dbccloginfo EXEC(@query);
			INSERT @results 
			SELECT @db_name
				,[file_name] = [f].[physical_name]
				,[count] = COUNT(*)
				,[vlf_in_use] = SUM(CASE WHEN [d].[status]=2 THEN 1 ELSE 0 END)
				,[vlf_total_sizeMB] = CAST(ROUND(SUM([d].[file_size]) / 1024.00 / 1024.00, 2) AS NUMERIC(20,2))
				,[vlf_single_largest_sizeMB] = CAST(ROUND(MAX([d].[file_size]) / 1024.00 / 1024.00, 2) AS NUMERIC(20,2))
				,[vlf_stdev_sizeMB] = CAST(ROUND(STDEV([d].[file_size]) / 1024.00 / 1024.00, 2) AS NUMERIC(20,2)) 
				,[tran_oldest_startdate] = (SELECT CAST([value] AS DATETIME) FROM @dbccopentran WHERE [key] = 'OLDACT_STARTTIME')
			FROM @dbccloginfo [d]
				INNER JOIN sys.master_files [f]
					ON [d].[fileid] = [f].[file_id]
						AND @db_name = DB_NAME([f].[database_id])
			GROUP BY [f].[physical_name];
		END
		ELSE 
		BEGIN
			INSERT INTO @dbccloginfo2012 EXEC (@query);
		
			INSERT @results 
			SELECT @db_name
				,[file_name] = [f].[physical_name]
				,[count] = COUNT(*)
				,[vlf_in_use] = SUM(CASE WHEN [d].[status]=2 THEN 1 ELSE 0 END)
				,[vlf_total_sizeMB] = CAST(ROUND(SUM([d].[file_size]) / 1024.00 / 1024.00, 2) AS NUMERIC(20,2))
				,[vlf_single_largest_sizeMB] = CAST(ROUND(MAX([d].[file_size]) / 1024.00 / 1024.00, 2) AS NUMERIC(20,2))
				,[vlf_stdev_sizeMB] = CAST(ROUND(STDEV([d].[file_size]) / 1024.00 / 1024.00, 2) AS NUMERIC(20,2))
				,[tran_oldest_startdate] = (SELECT CAST([value] AS DATETIME) FROM @dbccopentran WHERE [key] = 'OLDACT_STARTTIME')
			FROM @dbccloginfo2012 [d]
				INNER JOIN sys.master_files [f]
					ON [d].[fileid] = [f].[file_id]
						AND @db_name = DB_NAME([f].[database_id])
			GROUP BY [f].[physical_name];
		END

		DELETE FROM @dbccopentran;
		DELETE FROM @dbccloginfo;
		DELETE FROM @dbccloginfo2012;
		DELETE FROM @databases WHERE db_name = @db_name;
	END

	SELECT [db_name]
		,[file_name]
		,[vlf_count]
		,[vlf_in_use]
		,[vlf_total_sizeMB]
		,[vlf_single_largest_sizeMB]
		,[vlf_stdev_sizeMB]
		,[tran_oldest_startdate]
	FROM @results
	ORDER BY [db_name] DESC; 
END