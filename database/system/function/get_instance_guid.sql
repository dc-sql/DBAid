/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [system].[get_instance_guid]()
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT TOP(1) [value] AS [instance_guid]
	FROM [system].[configuration] 
	WHERE [key] = 'INSTANCE_GUID' COLLATE Latin1_General_CI_AS
)
