/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [system].[set_default_db_performance_configuration] (
	@db_name sysname
)
WITH ENCRYPTION
AS
BEGIN
	DECLARE @loop INT, @count INT, @path NVARCHAR(256), @logical_name sysname, @cmd NVARCHAR(1000);
	SET @count = 8;

	SELECT @path=SUBSTRING([physical_name], 0, LEN([physical_name])-(CHARINDEX('\', REVERSE([physical_name]))-2))
		,@logical_name = [name] 
	FROM sys.master_files 
	WHERE [type] = 0
		AND [database_id] = DB_ID(@db_name);

	SET @cmd = N'USE [master]; ALTER DATABASE [' + @db_name + '] SET AUTO_CREATE_STATISTICS ON WITH NO_WAIT;'
	EXEC sp_executesql @stmt=@cmd;
	SET @cmd = N'USE [master]; ALTER DATABASE [' + @db_name + '] SET AUTO_UPDATE_STATISTICS ON WITH NO_WAIT;'
	EXEC sp_executesql @stmt=@cmd;
	SET @cmd = N'USE [master]; ALTER DATABASE [' + @db_name + '] SET PARAMETERIZATION SIMPLE WITH NO_WAIT;'
	EXEC sp_executesql @stmt=@cmd;
	SET @cmd = N'USE [master]; ALTER DATABASE [' + @db_name + '] SET PAGE_VERIFY CHECKSUM WITH NO_WAIT;'
	EXEC sp_executesql @stmt=@cmd;
	SET @cmd = N'USE [master]; ALTER DATABASE [' + @db_name + '] SET AUTO_CLOSE OFF WITH NO_WAIT;'
	EXEC sp_executesql @stmt=@cmd;
	SET @cmd = N'USE [master]; ALTER DATABASE [' + @db_name + '] SET AUTO_SHRINK OFF WITH NO_WAIT;'
	EXEC sp_executesql @stmt=@cmd;

	SET @loop = 1;

	WHILE(@loop < @count)
	BEGIN
		SELECT @cmd = N'USE [master]; ALTER DATABASE [' 
			+ @db_name 
			+ N'] ADD FILE (NAME = N''' 
			+ @logical_name
			+ CAST(@loop+1 AS VARCHAR(2)) 
			+ N''', FILENAME='''
			+ @path 
			+ @logical_name
			+ CAST(@loop+1 AS VARCHAR(2))
			+ N'.ndf'
			+ N''', SIZE = 102400KB, FILEGROWTH = 102400KB);';

		EXEC sp_executesql @stmt=@cmd;
		SET @loop += 1;
	END
END
