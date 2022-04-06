/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Version]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @sender VARCHAR(228);
	DECLARE @subjectname VARCHAR(128);

	SELECT @sender = CAST(SERVERPROPERTY('Servername') AS VARCHAR(128)) + [setting] 
	FROM [deprecated].[tbparameters] 
	WHERE [parametername] = 'Client_domain';

	SELECT @subjectname = REPLACE(REPLACE(REPLACE(@sender, '@','_'),'.','_'),'\','#');

	SELECT @subjectname AS 'Servername'
			,getdate() AS 'Checkdate'
			,@@version AS 'Version';

	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
		UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;

	REVERT;
END
GO
