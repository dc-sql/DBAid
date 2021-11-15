/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Databases]
WITH ENCRYPTION
AS
SET NOCOUNT ON;

EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

DECLARE @client varchar(128)
select @client = replace(replace(replace(CAST(serverproperty('servername') as varchar(128))+[setting],'@','_'),'.','_'),'\','#')  from [deprecated].[tbparameters] where [parametername] = 'Client_domain'

select @client as 'Client', Getdate() as 'Checkdate',db.[name], CAST(ROUND(SUM(CAST([size] AS bigint))/128.00, 2) AS NUMERIC(20,2)) as size, 
 isnull(suser_sname(db.owner_sid),'~~UNKNOWN~~') as owner,
  db.database_id as dbid ,
  db.create_date as Created ,
  'Status ='+convert(sysname,db.state_desc) +'| Updateability='+ Case db.is_read_only when 0 then 'READ_WRITE' else 'READ_ONLY' end +
   '| Recovery='+convert(sysname,db.[recovery_model_desc] )+ '| Collation='+convert(sysname,isnull(db.[collation_name], convert(sysname,serverproperty('Collation')))) COLLATE DATABASE_DEFAULT as  [Status] ,
   db.[compatibility_level] as Compatailiity_level 
     from sys.databases db join sys.master_files mf on mf.database_id = db.database_id
     INNER JOIN [_dbaid].[dbo].[config_database] c ON db.database_id = c.database_id
     WHERE c.[is_enabled] = 1
     group by db.name, db.owner_sid, db.database_id, db.create_date, db.state_desc, db.is_read_only, db.[recovery_model_desc], db.[collation_name],  db.[compatibility_level]
     
	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
		UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;

REVERT;
