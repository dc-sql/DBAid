/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[get_instance_guid]()
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT TOP(1) CAST([value] AS UNIQUEIDENTIFIER) AS [guid] FROM [setting].[static_parameters] WHERE LOWER([name]) = N'guid'
)
