/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [system].[udf_get_module_cmd](@mod_name VARCHAR(128))
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT [cmd]
	FROM [system].[tbl_module_cmd]
	WHERE [module_name] = @mod_name
		AND [is_enabled] = 1
)
