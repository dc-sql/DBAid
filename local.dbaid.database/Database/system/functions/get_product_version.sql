/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [system].[get_product_version]()
RETURNS TABLE
WITH ENCRYPTION
RETURN(
    SELECT SUBSTRING(SUBSTRING(@@VERSION, 0, CHARINDEX('-', @@VERSION)), 0, CHARINDEX('(', @@VERSION)) AS [product_version],
           CAST(SERVERPROPERTY('Edition') AS sysname) AS [product_edition], 
           CAST(SERVERPROPERTY('ProductLevel') AS sysname) AS [service_pack],
           ISNULL(CAST(SERVERPROPERTY('ProductUpdateLevel') AS sysname), N'') AS [update_level], 
           PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS sysname), 4) AS [major], 
           PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS sysname), 3) AS [minor], 
           PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS sysname), 2) AS [build], 
           PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS sysname), 1) AS [revision]
)

