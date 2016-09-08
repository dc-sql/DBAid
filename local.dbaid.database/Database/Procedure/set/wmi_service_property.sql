/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [set].[wmi_service_property]
(
	@service_property_tbl [dbo].[udtt_service_property] READONLY
)
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @date DATETIME;
	SET @date = GETDATE();

	MERGE INTO [dbo].[wmi_service_property] AS [Target]
	USING (SELECT [class_object],[property], [value] FROM @service_property_tbl) AS [Source]
	ON [Target].[class_object] = [Source].[class_object]
	WHEN MATCHED THEN 
		UPDATE SET [Target].[property] = [Source].[property]
			,[Target].[value] = [Source].[value]
			,[Target].[lastseen] = @date
	WHEN NOT MATCHED BY TARGET THEN
		INSERT ([class_object],
				[property],
				[value])
		VALUES ([Source].[class_object],
				[Source].[property],
				[Source].[value])
	WHEN NOT MATCHED BY SOURCE 
		AND [lastseen] < DATEADD(MONTH, -1, GETDATE()) THEN
		DELETE;
END
GO

