/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE VIEW [info].[instance]
WITH ENCRYPTION
AS
SELECT [name]
	,[value_in_use]
FROM [master].[sys].[configurations]
