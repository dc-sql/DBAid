/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [system].[get_hexadecimal] (@binvalue VARBINARY(256))
RETURNS @return TABLE ([hexvalue] VARCHAR(514))
WITH ENCRYPTION
AS
BEGIN
	DECLARE @charvalue VARCHAR(514), @i INT, @length INT, @hexstring CHAR(16);
	SELECT @charvalue = '0x', @i = 1, @length = DATALENGTH(@binvalue), @hexstring = '0123456789ABCDEF';
	
	WHILE (@i <= @length)
	BEGIN
	  DECLARE @tempint INT, @firstint INT, @secondint INT;
	  
	  SELECT @tempint = CONVERT(INT, SUBSTRING(@binvalue,@i,1))
		,@firstint = FLOOR(@tempint/16)
		,@secondint = @tempint - (@firstint*16)
		,@charvalue = @charvalue + SUBSTRING(@hexstring, @firstint+1, 1) + SUBSTRING(@hexstring, @secondint+1, 1)
		,@i = @i + 1;
	END

	INSERT INTO @return VALUES(@charvalue);
	
	RETURN;
END
GO
