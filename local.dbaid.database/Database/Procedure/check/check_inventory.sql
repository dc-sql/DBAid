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
	
	EXECUTE AS LOGIN = N'$(DatabaseName)';

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

    INSERT INTO @check
    SELECT CAST(s.[Value] AS sysname) 
            + N',' 
            + CAST(SERVERPROPERTY('MachineName') AS sysname) 
            + N'\' 
            + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS sysname), N'MSSQLSERVER') 
            + N'\' + D.[name]
            + N',Microsoft SQL Server '
            + CASE LEFT(CAST(SERVERPROPERTY('ProductVersion') AS sysname), 4)
                WHEN N'15.0' THEN N'2019 '
                WHEN N'14.0' THEN N'2017 '
                WHEN N'13.0' THEN N'2016 '
                WHEN N'12.0' THEN N'2014 '
                WHEN N'11.0' THEN N'2012 '
                WHEN N'10.5' THEN N'2008 R2 '
                WHEN N'10.0' THEN N'2008 '
                WHEN N'9.0.' THEN N'2005 '
                WHEN N'8.0.' THEN N'2000 '
            END
            + REPLACE(REPLACE(REPLACE(REPLACE(CAST(SERVERPROPERTY('Edition') AS sysname), N'(64-bit)', N'64-bit'), N': Core-based Licensing', N''), N'Edition', N''), N'  ', N' ')
            + N',' + CAST(SERVERPROPERTY('ProductLevel') AS sysname) 
            + ISNULL(N'-' + CAST(SERVERPROPERTY('ProductUpdateLevel') AS sysname), N'') 
            + ISNULL(N'-' + CAST(SERVERPROPERTY('ProductBuildType') AS sysname), N'') 
            , N'OK'
    FROM [dbo].[static_parameters] s, sys.databases D 
    WHERE s.[name] = N'TENANT_NAME'
    /* exclude system databases & _dbaid as none of these are loaded into CMDB */
    AND D.[name] NOT IN ('_dbaid', 'master', 'model', 'msdb', 'tempdb');

    SELECT [message], [state] FROM @check;

	REVERT;
END



