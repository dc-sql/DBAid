/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[db_writeable](@database_name sysname)
RETURNS BIT
WITH ENCRYPTION
AS
BEGIN

IF DB_ID(@database_name) IS NULL
BEGIN
	RETURN 0;
END
IF EXISTS(SELECT [name] FROM [sys].[databases] 
			WHERE DATABASEPROPERTYEX([name], 'Updateability') = 'READ_ONLY'
				AND [name] = @database_name)
			BEGIN
				RETURN 0;
			END

			RETURN 1;

END;
GO