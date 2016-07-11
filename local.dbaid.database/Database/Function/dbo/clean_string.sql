﻿/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[clean_string](@dirty_string NVARCHAR(MAX))
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@dirty_string,'  ',' '),CHAR(10),''),CHAR(13),''),'","','";"'))) AS [string]
)

