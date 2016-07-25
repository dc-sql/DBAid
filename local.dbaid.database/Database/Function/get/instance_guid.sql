/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [get].[instance_guid]()
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT TOP(1) [value] AS [guid] 
	FROM [setting].[static_parameters] 
	WHERE [key] = N'guid' COLLATE Latin1_General_CI_AS
)
