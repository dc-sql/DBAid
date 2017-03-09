/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_instance_sysconfigurations]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [name]
		,[value_in_use]
	FROM [master].[sys].[configurations]
END
