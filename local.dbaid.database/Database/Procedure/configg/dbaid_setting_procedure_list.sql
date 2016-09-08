/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[dbaid_setting_procedure_list]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT * FROM [setting].[procedure_list];
END

