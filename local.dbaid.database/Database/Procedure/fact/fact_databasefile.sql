/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[databasefile]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	SELECT [database_name]
      ,[file_name]
      ,[type_desc]
      ,[state_desc]
      ,[physical_name]
      ,[max_size_mb]
      ,[auto_grow]
      ,[is_read_only] 
	FROM [info].[databasefile]

	REVERT;
END
