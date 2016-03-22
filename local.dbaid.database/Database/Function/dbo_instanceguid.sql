/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[instanceguid]()
RETURNS 
@output TABLE
(
	[guid] UNIQUEIDENTIFIER
)
WITH ENCRYPTION
AS
BEGIN
	INSERT INTO @output
		SELECT TOP(1) CAST([value] AS UNIQUEIDENTIFIER) FROM [dbo].[static_parameters] WHERE LOWER([name]) = N'guid';

	RETURN;
END
