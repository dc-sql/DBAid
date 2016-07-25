/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[serverobject]
WITH ENCRYPTION
AS
BEGIN 
	SET NOCOUNT ON;

	SELECT * FROM [info].[serverobject];
END