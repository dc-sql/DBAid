/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [dbo].[set_service_property]
(
	@class_object NVARCHAR(300),
	@property NVARCHAR(128),
	@value SQL_VARIANT = NULL
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @date DATETIME;
	SET @date = GETDATE();

	IF EXISTS (SELECT 1 FROM [dbo].[service] WHERE [class_object] = @class_object AND [property] = @property)
	BEGIN
		UPDATE [dbo].[service] SET [value] = @value, [lastseen] = @date WHERE [class_object] = @class_object AND [property] = @property;
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[service] ([class_object], [property], [value], [lastseen]) VALUES (@class_object, @property, @value, @date);
	END

	DELETE FROM [dbo].[service] WHERE [lastseen] < DATEADD(MONTH, -1, GETDATE());
END
GO

