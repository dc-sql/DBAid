/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[dbaid_setting_wmi_service_query]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT * FROM [setting].[wmi_service_query];
END

