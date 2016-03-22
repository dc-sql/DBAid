USE [_dbaid]
GO

IF EXISTS (SELECT name FROM sysobjects WHERE name = 'generate_rsa_key')
   DROP FUNCTION generate_rsa_key;
GO

IF EXISTS (SELECT name FROM sys.assemblies WHERE name = 'dbaid.rsa.keygen')
   DROP ASSEMBLY [dbaid.rsa.keygen];
GO

IF EXISTS (SELECT name FROM sys.database_principals WHERE [name] = 'dbaid_clr_login')
   DROP USER [dbaid_clr_login];
GO

USE [master]
GO

IF EXISTS (SELECT name FROM sys.server_principals WHERE [name] = N'dbaid_clr_login')
	DROP LOGIN [dbaid_clr_login]
GO

IF EXISTS (SELECT name FROM sys.asymmetric_keys WHERE name = 'dbaid_rsa_keygen')
   DROP ASYMMETRIC KEY [dbaid_rsa_keygen];
GO

CREATE ASYMMETRIC KEY [dbaid_rsa_keygen]
FROM EXECUTABLE FILE = 'D:\DBAid\server.dbaid.keygen.dll'
GO

CREATE LOGIN [dbaid_clr_login] FROM ASYMMETRIC KEY [dbaid_rsa_keygen]
GO

ALTER LOGIN [dbaid_clr_login] DISABLE
GO

GRANT EXTERNAL ACCESS ASSEMBLY TO [dbaid_clr_login] 
GO

USE [_dbaid]
GO

CREATE USER [dbaid_clr_login] FOR LOGIN [dbaid_clr_login]
GO
/* Make sure the snk file is with the dll in the same folder, or the asymmetric key won't generate */
CREATE ASSEMBLY [dbaid.rsa.keygen] FROM 'D:\DBAid\server.dbaid.keygen.dll'
WITH PERMISSION_SET = EXTERNAL_ACCESS;
GO

CREATE FUNCTION generate_rsa_key() 
RETURNS TABLE
(
   private_key NVARCHAR(4000),
   public_key NVARCHAR(4000)
)
AS EXTERNAL NAME [dbaid.rsa.keygen].[dbaid].[generate_rsa_key];
GO

SELECT * FROM generate_rsa_key();
GO