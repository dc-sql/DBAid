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
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)')) 
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)')) 
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([name]) = N'$(DatabaseName)' AND LOWER([type]) = 'r')
	CREATE ROLE [$(DatabaseName)];
GO

/* Instance Security */
GRANT VIEW ANY DEFINITION							TO [$(CollectorServiceAccount)];
GRANT VIEW ANY DATABASE								TO [$(CollectorServiceAccount)];
GRANT VIEW SERVER STATE								TO [$(CollectorServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa]	TO [$(CollectorServiceAccount)];
GRANT VIEW ANY DEFINITION							TO [$(CheckServiceAccount)];
GRANT VIEW ANY DATABASE								TO [$(CheckServiceAccount)];
GRANT VIEW SERVER STATE								TO [$(CheckServiceAccount)];
GRANT IMPERSONATE ON LOGIN::[$(DatabaseName)_sa]	TO [$(CheckServiceAccount)];

/* Role security */
GRANT EXECUTE ON [dbo].[xp_logevent]			TO [public];
GRANT EXECUTE ON [dbo].[xp_enumerrorlogs]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_readerrorlog]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_readerrorlog]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_fixeddrives]			TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_logininfo]			TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_sqlagent_enum_jobs]	TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_validatelogins]		TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_executesql]			TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[xp_instance_regread]	TO [$(DatabaseName)];
GO

--EXEC sp_addsrvrolemember @loginame=N'$(CollectorServiceAccount)', @rolename=N'securityadmin';
EXEC sp_addrolemember @membername=N'$(CollectorServiceAccount)', @rolename=N'$(DatabaseName)';
EXEC sp_addrolemember @membername=N'$(CheckServiceAccount)', @rolename=N'$(DatabaseName)';
GO

/* #######################################################################################################################################
#	
#	Apply permissions to [msdb] database
#
####################################################################################################################################### */
USE [msdb];
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CollectorServiceAccount)'))
	CREATE USER [$(CollectorServiceAccount)] FOR LOGIN [$(CollectorServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) IN ('u','s') AND LOWER(name) = LOWER('$(CheckServiceAccount)'))
	CREATE USER [$(CheckServiceAccount)] FOR LOGIN [$(CheckServiceAccount)];
GO
IF NOT EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE LOWER([type]) = 'r' AND LOWER([name]) = '$(DatabaseName)')
	CREATE ROLE [$(DatabaseName)];
GO

GRANT EXECUTE ON [dbo].[sp_help_jobhistory]	TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sp_help_jobactivity] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[agent_datetime] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_configure_sp] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_account_sp] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_profileaccount_sp] TO [$(DatabaseName)];
GRANT EXECUTE ON [dbo].[sysmail_help_principalprofile_sp] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_monitor_primary] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_monitor_secondary] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_primary_secondaries] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_secondary_databases] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[log_shipping_secondary] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobs] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobhistory] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobschedules] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysschedules] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobactivity] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_plans] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_subplans] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_log] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmaintplan_logdetail] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysproxies] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysjobsteps] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysmail_server] TO [$(DatabaseName)];
GRANT SELECT ON [dbo].[sysoperators] TO [$(DatabaseName)];
GO

EXEC sp_addrolemember @membername=N'$(DatabaseName)', @rolename=N'SQLAgentReaderRole';
EXEC sp_addrolemember @membername=N'$(CollectorServiceAccount)', @rolename=N'$(DatabaseName)';
EXEC sp_addrolemember @membername=N'$(CheckServiceAccount)', @rolename=N'$(DatabaseName)';
GO

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

GRANT EXECUTE ON SCHEMA::[get] TO [collect];
GRANT EXECUTE ON SCHEMA::[report] TO [collect];
GRANT EXECUTE ON SCHEMA::[log] TO [collect];
GRANT EXECUTE ON SCHEMA::[configg] TO [collect];

GRANT EXECUTE ON SCHEMA::[get] TO [check];
GRANT EXECUTE ON SCHEMA::[check] TO [check];
GRANT EXECUTE ON SCHEMA::[chart] TO [check];
GRANT EXECUTE ON [dbo].[dbaid_inventory] TO [check];
GO

EXEC sp_addrolemember 'collect', '$(CollectorServiceAccount)';
EXEC sp_addrolemember 'check', '$(CheckServiceAccount)';
GO