CREATE FUNCTION [dbo].[get_instance_version] (@dummy bit)
RETURNS 
@output TABLE
(
	string nvarchar(4000)
)
WITH ENCRYPTION
AS
BEGIN
    DECLARE @edition nvarchar(4000),
            @patch_level sysname;
    SELECT @edition = CAST([Value] AS sysname) + N',' + CAST(SERVERPROPERTY('MachineName') AS sysname) + N'\' + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS sysname), N'MSSQLSERVER') + N',Microsoft SQL Server ' + REPLACE(REPLACE(REPLACE(REPLACE(CAST(SERVERPROPERTY('Edition') AS sysname), N'(64-bit)', N'64-bit'), N': Core-based Licensing', N''), N'Edition', N''), N'  ', N' ')
           ,@patch_level = CAST(SERVERPROPERTY('ProductLevel') AS sysname) + ISNULL(N'-' + CAST(SERVERPROPERTY('ProductUpdateLevel') AS sysname), N'') + ISNULL(N'-' + CAST(SERVERPROPERTY('ProductBuildType') AS sysname), N'') + N',' + CAST(SERVERPROPERTY('ProductVersion') AS sysname)
    FROM [dbo].[static_parameters] WHERE [name] = N'TENANT_NAME';

	INSERT INTO @output
        SELECT N'0 mssql_' 
               + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS sysname), N'MSSQLSERVER') 
               + N' - ' 
               + CASE RIGHT(@edition, 3)
                   WHEN N'bit' THEN @edition
                   ELSE @edition + N'32-bit'
                 END
               + N',' 
               + @patch_level;	
    RETURN
END
GO

GRANT SELECT ON [dbo].[get_instance_version] TO [monitor]
GO
GRANT SELECT ON [dbo].[get_instance_version] TO [admin]
GO
