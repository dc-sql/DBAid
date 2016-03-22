/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE VIEW [info].[serverobject]
WITH ENCRYPTION
AS
SELECT [type]
	,[name]
	,[configuration]
FROM [dbo].[getobjectconfig]()
