/* #######################################################################################################################################
#	
#	Apply permissions to [master] database
#
####################################################################################################################################### */
USE [master];
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)')) 
	CREATE LOGIN [$(CollectorServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[server_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)')) 
	CREATE LOGIN [$(CheckServiceAccount)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];
GO

/* Instance Security */
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa] TO [$(CollectorServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa] TO [$(CheckServiceAccount)];

/* #######################################################################################################################################
#	
#	Apply permissions to [monitoring] database
#
####################################################################################################################################### */
USE [$(DatabaseName)];
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)'))
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)'))
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO

GRANT EXECUTE ON SCHEMA::[report] TO [collect];
GRANT EXECUTE ON SCHEMA::[log] TO [collect];
GRANT EXECUTE ON SCHEMA::[configg] TO [collect];
GRANT EXECUTE ON [dbo].[dbaid_inventory] TO [collect];
GRANT EXECUTE ON [dbo].[procedure_list] TO [collect];
GRANT EXECUTE ON [dbo].[instance_tag] TO [collect];

GRANT EXECUTE ON SCHEMA::[check] TO [check];
GRANT EXECUTE ON SCHEMA::[chart] TO [check];
GRANT EXECUTE ON [dbo].[dbaid_inventory] TO [check];
GRANT EXECUTE ON [dbo].[procedure_list] TO [check];
GRANT EXECUTE ON [dbo].[instance_tag] TO [check];
GO

EXEC sp_addrolemember 'collect', '$(CollectorServiceAccount)';
EXEC sp_addrolemember 'check', '$(CheckServiceAccount)';
GO