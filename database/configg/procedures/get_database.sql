/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_database]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'DATABASE' AS [heading], 'Databases' AS [subheading], 'This is a list of databases on the instance' AS [comment]

	DECLARE @cmd NVARCHAR(MAX);
	DECLARE @columns NVARCHAR(MAX);
	DECLARE @colist AS TABLE(col NVARCHAR(128));

	INSERT INTO @colist
		SELECT [name] 
		FROM [master].sys.all_columns
		WHERE [object_id] = OBJECT_ID(N'sys.databases')
			AND [name] NOT LIKE N'%[_]id'
			AND [name] NOT LIKE 'log_reuse_wait%'
		ORDER BY [column_id];

	SELECT @columns = COALESCE(@columns + ', ', '') 
		+ CASE WHEN [col] = N'owner_sid' THEN N'SUSER_SNAME(owner_sid) AS [owner]' 
			WHEN [col] LIKE N'%[_]desc' THEN [col] + N' AS [' + REPLACE([col],'_desc',']')
			ELSE [col] END
	FROM @colist
	WHERE [col] + N'_desc' NOT IN (SELECT [col] FROM @colist) 

	SET @cmd = N'SELECT ' + @columns + N' FROM [master].[sys].[databases];';

	EXEC(@cmd);
END
