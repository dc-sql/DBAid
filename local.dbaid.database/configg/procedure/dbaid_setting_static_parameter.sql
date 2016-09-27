/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[dbaid_setting_static_parameter]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT * FROM [setting].[static_parameters];
END

