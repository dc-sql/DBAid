/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[service]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @flags TABLE([flag] INT, [enabled] BIT, [global] BIT, [session] INT);
	INSERT INTO @flags EXEC('DBCC TRACESTATUS (-1) WITH NO_INFOMSGS');

	SELECT [hierarchy]
		,[property]
		,CAST([value] AS NVARCHAR(4000)) AS [value]
	FROM [info].[service]
	WHERE [property] NOT IN (N'ProcessID', N'SqlCharSetName', N'SqlSortOrderName', N'LicenseType', N'NumLicenses')
	UNION ALL
	SELECT N'SqlServiceInstanceProperty/' + CASE WHEN @@SERVICENAME = N'MSSQLSERVER' THEN @@SERVICENAME ELSE N'MSSQL$' + @@SERVICENAME END AS [hierarchy]
		,N'TraceFlags' AS [property]
		,STUFF((SELECT N', ' + CAST([flag] AS NCHAR(4)) AS [text()] FROM @flags WHERE [global] = 1 AND [enabled] = 1 FOR XML PATH('')), 1, 2, '') AS [value]
END
