/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[inventory]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

    /* Using # as separator for ServerName\InstanceName\DatabaseName as an instance or database with [lower case?] "n" as first character
         leads to a "\n" combination that Checkmk interprets as a newline character. Does not seem to be possible to escape this combination
         to stop it happening.
    */
    INSERT INTO @check
    SELECT CAST(s.[value] AS sysname) 
            + N',' 
            + CAST(SERVERPROPERTY('MachineName') AS sysname) 
            + N'#' 
            + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS sysname), N'MSSQLSERVER') 
            + N'#' + D.[name]
            , N'OK'
    FROM [$(DatabaseName)].[dbo].[static_parameters] s, sys.databases D 
      INNER JOIN [$(DatabaseName)].[dbo].[config_database] c ON D.[database_id] = c.[database_id]
    WHERE s.[name] = N'TENANT_NAME'
      /* exclude system databases & _dbaid as none of these are loaded into CMDB */
      AND D.[name] NOT IN (N'_dbaid', N'master', N'model', N'msdb', N'tempdb')
      AND ((D.[state_desc] NOT IN (N'OFFLINE')) OR (D.[state_desc] IN (N'OFFLINE') AND c.[is_enabled] = 1));

    IF (SELECT COUNT(*) FROM @check) = 0
        INSERT INTO @check ([message], [state]) VALUES (N'No user databases found.', N'NA');

    SELECT [message], [state] FROM @check;

	REVERT;
END



