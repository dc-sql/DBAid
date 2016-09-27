/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Version]
WITH ENCRYPTION
AS

SET NOCOUNT ON;
 
Declare @sender varchar(228)
Declare @subjectname varchar(128)

select @sender = CAST(serverproperty('servername') as varchar(128)) + [setting] from [deprecated].[tbparameters] where [parametername] = 'Client_domain'
select @subjectname = replace(replace(replace (@sender, '@','_'),'.','_'),'\','#')

select @subjectname as 'Servername',getdate() as 'Checkdate',@@version as 'Version'

	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
		UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;
GO
