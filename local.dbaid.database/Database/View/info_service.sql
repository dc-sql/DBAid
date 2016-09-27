/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE VIEW [info].[service]
WITH ENCRYPTION 
AS
SELECT [hierarchy]
	,[property]
	,[value]
FROM [dbo].[getserviceinfo]()
