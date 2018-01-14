/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [dbo].[insert_service]
(
	@hierarchy NVARCHAR(260),
	@property NVARCHAR(128),
	@value SQL_VARIANT = NULL
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @date DATETIME;
	SET @date = GETDATE();

	--added to always get the latest data for localadmins as they can be added and removed - fudge with timer
	DELETE FROM [dbo].[service] WHERE [hierarchy] LIKE '%Win32_GroupUser/Local_Admins%' AND [lastseen] < DATEADD(MINUTE, -1, GETDATE());

	IF EXISTS (SELECT 1 FROM [dbo].[service] WHERE [hierarchy] = @hierarchy AND [property] = @property)
	BEGIN
		UPDATE [dbo].[service] SET [value] = @value, [lastseen] = @date WHERE [hierarchy] = @hierarchy AND [property] = @property;
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[service] ([hierarchy], [property], [value], [lastseen]) VALUES (@hierarchy, @property, @value, @date);
	END

	DELETE FROM [dbo].[service] WHERE [lastseen] < DATEADD(MONTH, -1, GETDATE());
END
GO

