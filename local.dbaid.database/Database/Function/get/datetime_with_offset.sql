/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [get].[datetime_with_offset]  
(
	@date DATETIME = NULL
)
RETURNS @values TABLE
(
	[date] CHAR(29) NULL
)
AS
BEGIN
	DECLARE @offset_minute INT;
	DECLARE @offset_string CHAR(6);
	
	SET @offset_minute = DATEDIFF(MINUTE, GETUTCDATE(), GETDATE());

	SET @offset_string = CASE WHEN @offset_minute > 0 THEN '+' ELSE '-' END
			+ RIGHT('00' + CAST(@offset_minute / 60 AS VARCHAR(2)), 2) 
			+ ':' 
			+ RIGHT('00' + CAST(@offset_minute % 60 AS VARCHAR(2)), 2);

	INSERT INTO @values /* Stuffing 'T' with format 121, as formats 126 or 127 doesn't guarantee to return millisecond */
		SELECT STUFF(CONVERT(CHAR(23), @date, 121), 11, 1, 'T') + @offset_string
	
	RETURN
END
GO
