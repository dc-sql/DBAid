/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[cleanstring](@dirty_string NVARCHAR(MAX))
RETURNS 
@output TABLE
(
	[string] NVARCHAR(MAX)
)
WITH ENCRYPTION
AS
BEGIN
	INSERT INTO @output 
		SELECT LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@dirty_string,'  ',' '),CHAR(10),''),CHAR(13),''),'","','";"')));

	RETURN;
END

GO

GRANT SELECT ON [dbo].[cleanstring] TO [monitor]
GO
GRANT SELECT ON [dbo].[cleanstring] TO [admin]
GO

