/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[maintenanceplan]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	SELECT * FROM [info].[maintenanceplan];

	REVERT;
END
