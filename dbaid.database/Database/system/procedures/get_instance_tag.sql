/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [system].[get_instance_tag]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sanitise BIT, @domain VARCHAR(128), @DetectedOS NVARCHAR(20);

	SELECT @sanitise=CAST([value] AS BIT) FROM [system].[configuration] WHERE [key] = N'SANITISE_COLLECTOR_DATA';

  /* sys.dm_os_host_info is relatively new (SQL 2017+ despite what BOL says; not from 2008). If it's there, query it (result being 'Linux' or 'Windows'). If not there, it's Windows. */
  IF EXISTS (SELECT 1 FROM sys.system_objects WHERE [name] = N'dm_os_host_info' AND [schema_id] = SCHEMA_ID(N'sys'))
    IF ((SELECT [host_platform] FROM sys.dm_os_host_info) LIKE N'%Linux%')
    BEGIN
      SET @DetectedOS = 'Linux';
    END
    ELSE IF ((SELECT SERVERPROPERTY('EngineEdition')) = 8) 
        SET @DetectedOS = 'AzureManagedInstance';
      ELSE 
        SET @DetectedOS = 'Windows'; /* If it's not Linux or Azure Managed Instance, then we assume Windows. */
  ELSE 
    SELECT @DetectedOS = N'Windows'; /* if dm_os_host_info object doesn't exist, then we assume Windows. */

  IF @DetectedOS = N'Windows'
  BEGIN  
    EXEC [master].[dbo].[xp_regread] @rootkey='HKEY_LOCAL_MACHINE'
      ,@key='SYSTEM\ControlSet001\Services\Tcpip\Parameters\'
      ,@value_name='Domain'
      ,@value=@domain OUTPUT;
  END

	IF (@sanitise = 1)
	BEGIN
		SELECT [instance_tag]=CAST([value] AS VARCHAR(36)) FROM [system].[configuration] WHERE [key] = N'INSTANCE_GUID'
	END
	ELSE
	BEGIN
    IF @DetectedOS = N'Windows'
		  SELECT [instance_tag]=CAST(SERVERPROPERTY('MachineName') AS VARCHAR(128)) + '_' +  @@SERVICENAME + '_' + REPLACE(@domain, '.', '_');
    ELSE
      SELECT [instance_tag]=CAST(SERVERPROPERTY('MachineName') AS VARCHAR(128)) + '_' +  @@SERVICENAME;
	END
END
