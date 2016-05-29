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

	SELECT * FROM [info].[databasefile]
END
