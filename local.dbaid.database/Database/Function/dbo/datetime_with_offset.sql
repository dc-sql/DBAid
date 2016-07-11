/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE FUNCTION [dbo].[datetime_with_offset]  
(
	@date DATETIME = NULL
)
RETURNS TABLE
RETURN(
	WITH Offset
	AS
	(
		SELECT DATEDIFF(MINUTE, GETUTCDATE(), GETDATE()) AS [offset_minute]
	)
	SELECT STUFF(CONVERT(CHAR(23), @date, 121), 11, 1, 'T') 
		+ CASE WHEN [offset_minute] > 0 THEN '+' ELSE '-' END
		+ RIGHT('00' + CAST([offset_minute] / 60 AS VARCHAR(2)), 2) 
		+ ':' 
		+ RIGHT('00' + CAST([offset_minute] % 60 AS VARCHAR(2)), 2) AS [date]
	FROM Offset
)
