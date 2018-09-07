/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_database_mirroring]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'Database' AS [heading], 'Mirroring' AS [subheading], 'This is a list of mirrored databases' AS [comment]

	SELECT DB_NAME([mirroring].[database_id]) AS [database_name]
		,[mirroring].[mirroring_role_desc] 
		,[mirroring].[mirroring_safety_level_desc]
		,[mirroring].[mirroring_partner_instance]
		,[mirroring].[mirroring_partner_name]
		,[mirroring].[mirroring_witness_name]
	FROM [master].[sys].[database_mirroring] [mirroring] 
	WHERE [mirroring].[mirroring_guid] IS NOT NULL;
END
