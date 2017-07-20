/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_instance]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'OK' AS [state]
		,[clean_string] AS [message]
	FROM [system].[get_clean_string](@@VERSION);
END


