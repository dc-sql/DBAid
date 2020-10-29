/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [system].[get_split_string]
(
	@str VARCHAR(MAX), 
	@delimiter VARCHAR(10)
)
RETURNS @items TABLE
(
	[value] VARCHAR(100) NULL
)
WITH ENCRYPTION
AS
BEGIN
	DECLARE @xml XML;
	SET @xml = CAST(('<X>' + REPLACE(@str, @delimiter,'</X><X>') + '</X>') AS XML);

	INSERT INTO @items SELECT N.value('.', 'VARCHAR(MAX)') AS [value] FROM @xml.nodes('X') AS T(N);
	RETURN;
END
GO
