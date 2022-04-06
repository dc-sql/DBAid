/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Databases]
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

    DECLARE @client VARCHAR(128);

    SELECT @client = REPLACE(REPLACE(REPLACE(CAST(SERVERPROPERTY('Servername') AS VARCHAR(128)) + [setting], '@', '_'), '.', '_'), '\', '#')
    FROM [$(DatabaseName)].[deprecated].[tbparameters] 
    WHERE [parametername] = 'Client_domain';

    SELECT @client AS [Client]
            ,GETDATE() AS [Checkdate]
            ,db.[name]
            ,CAST(ROUND(SUM(CAST([size] AS BIGINT))/128.00, 2) AS NUMERIC(20,2)) AS [size]
            ,ISNULL(SUSER_SNAME(db.[owner_sid]), '~~UNKNOWN~~') AS [owner]
            ,db.[database_id] AS [dbid]
            ,db.[create_date] AS [Created]
            ,'Status =' + CONVERT(SYSNAME, db.[state_desc]) 
                + '| Updateability=' + CASE db.[is_read_only] WHEN 0 THEN 'READ_WRITE' ELSE 'READ_ONLY' END 
                + '| Recovery=' + CONVERT(SYSNAME, db.[recovery_model_desc] )
                + '| Collation=' + CONVERT(SYSNAME, ISNULL(db.[collation_name], CONVERT(SYSNAME, SERVERPROPERTY('Collation')))) COLLATE DATABASE_DEFAULT AS [Status]
            ,db.[compatibility_level] AS [Compatailiity_level]
    FROM sys.databases db 
      INNER JOIN sys.master_files mf ON mf.database_id = db.database_id
      INNER JOIN [$(DatabaseName)].[dbo].[config_database] c ON db.database_id = c.database_id
    /* Logic for SACM CMDB reconciliation:
        If database is OFFLINE and monitoring [is_enabled] is False, don't include as it is assumed planned outage/pending decommission. Update CMDB.
        If database is OFFLINE and monitoring [is_enabled] is True, include as it is assumed there's a problem (which is why the database is OFFLINE) or someone hasn't updated monitoring & CMDB for a decommission.
        If database is NOT OFFLINE and monitoring [is_enabled] is False, include as it is assumed planned outage or similar to prevent alerts. It should still appear for CMDB reconciliation. If not, set CI to Non Discoverable in CMDB.
        If database id NOT OFFLINE and monitoring [is_enabled] is True, include it as this is the status quo for normal operation.
    */
    WHERE (db.[state_desc] IN (N'OFFLINE') AND c.[is_enabled] = 1)
       OR (db.[state_desc] NOT IN (N'OFFLINE'))
    GROUP BY db.[name], db.[owner_sid], db.[database_id], db.[create_date], db.[state_desc], db.[is_read_only], db.[recovery_model_desc], db.[collation_name], db.[compatibility_level];
     
    IF (SELECT [value] FROM [$(DatabaseName)].[dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
	    UPDATE [$(DatabaseName)].[dbo].[procedure] 
        SET [last_execution_datetime] = GETDATE() 
        WHERE [procedure_id] = @@PROCID;

    REVERT;
END