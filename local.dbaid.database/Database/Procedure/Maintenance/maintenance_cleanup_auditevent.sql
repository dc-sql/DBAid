/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [maintenance].[cleanup_auditevent]
(
	@olderthan_day INT = 7
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF (@olderthan_day > 0) SET @olderthan_day = @olderthan_day*-1

	DELETE FROM [audit].[event] WHERE [postdate] < DATEADD(DAY,@olderthan_day,GETDATE())
END
