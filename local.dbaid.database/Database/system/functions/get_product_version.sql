/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [system].[get_product_version]()
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT [product_version], [service_pack], [major], [minor], [build], [patch]
	FROM (SELECT SUBSTRING(SUBSTRING(@@VERSION, 0, CHARINDEX('-', @@VERSION)), 0, CHARINDEX('(', @@VERSION)) AS [product_version]
	,SERVERPROPERTY('ProductLevel') AS [service_pack]
	,CAST([build].[number] AS INT) AS [build_number]
	,CASE [build].[position] 
		WHEN 1 THEN 'major'
		WHEN 2 THEN 'minor'
		WHEN 3 THEN 'build'
		WHEN 4 THEN 'patch' END AS [build_name]
	FROM (SELECT string.split.value('(./text())[1]', 'NVARCHAR(10)'), ROW_NUMBER() OVER(ORDER BY string.split)
	FROM (SELECT x = CONVERT(XML, '<a>' + REPLACE(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), '.', '</a><a>') + '</a>').query('.')) AS xmlstr 
		CROSS APPLY x.nodes('a') AS string(split)) AS [build]([number], [position])
	) AS [SourceTable]
	PIVOT
	(
		MIN([SourceTable].[build_number])
		FOR [SourceTable].[build_name] IN ([major], [minor], [build], [patch])
	) AS [PivotTable]
)

