/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

SET NOEXEC OFF;
GO
USE [master];
GO

IF (DB_ID(N'$(DatabaseName)') IS NOT NULL)
BEGIN
	DECLARE @backupsql NVARCHAR(MAX);
	/* doesn't exist in DBAid 10
	IF (OBJECT_ID(N'[$(DatabaseName)].[dbo].[toggle_audit_service]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'EXEC [$(DatabaseName)].[dbo].[toggle_audit_service] @enable_login_audit=0,@enable_blocked_process_audit=0,@enable_deadlock_audit=0,@enable_mirror_state_audit=0,@enable_server_ddl_audit=0,@enable_db_security_audit=0';
		EXEC sp_executesql @stmt=@backupsql;
	END
	--*/
	/* doesn't exist in DBAid 10, don't really want it either (legacy daily checks)
	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_deprecated_tbparameters') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[deprecated].[tbparameters]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT [parametername],[setting],[status],[comments] INTO [tempdb].[dbo].[$(DatabaseName)_deprecated_tbparameters] FROM [$(DatabaseName)].[deprecated].[tbparameters]';
		EXEC sp_executesql @stmt=@backupsql;
	END
	--*/

	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_config_alwayson') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[checkmk].[config_alwayson]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT [ag_id],[ag_name],[ag_state_alert],[ag_state_is_enabled],[ag_role],[ag_role_alert],[ag_role_is_enabled] INTO [tempdb].[dbo].[$(DatabaseName)_backup_config_alwayson] FROM [$(DatabaseName)].[checkmk].[config_alwayson]';
		EXEC sp_executesql @stmt=@backupsql;
	END

	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_config_database') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[checkmk].[config_database]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_config_database] FROM [$(DatabaseName)].[checkmk].[config_database]';
		EXEC sp_executesql @stmt=@backupsql;
	END

	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_config_agentjob') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[checkmk].[config_agentjob]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_config_agentjob] FROM [$(DatabaseName)].[checkmk].[config_agentjob]';
		EXEC sp_executesql @stmt=@backupsql;
	END

	/* doesn't exist in DBAid 10 as yet, may be added later
	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_config_perfcounter') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[dbo].[config_perfcounter]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_config_perfcounter] FROM [$(DatabaseName)].[dbo].[config_perfcounter]';
		EXEC sp_executesql @stmt=@backupsql;
	END
	--*/

	/* assuming DBAid 10 table system.configuration is to be used instead of old dbo.static_parameters. */
	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_configuration') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[system].[configuration]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_configuration] FROM [$(DatabaseName)].[system].[configuration] WHERE [key] NOT IN (''PUBLIC_ENCRYPTION_KEY'')';
		EXEC sp_executesql @stmt=@backupsql;
	END

	/* doesn't exist in DBAid 10 (if deploying by dacpac - version is recorded in msdb)
	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_version') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[dbo].[version]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_version] FROM [$(DatabaseName)].[dbo].[version]';
		EXEC sp_executesql @stmt=@backupsql;
	END
	--*/

	/* doesn't exist in DBAid 10
	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_procedure') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[dbo].[procedure]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_procedure] FROM [$(DatabaseName)].[dbo].[procedure]';
		EXEC sp_executesql @stmt=@backupsql;
	END
	--*/

	IF (OBJECT_ID(N'tempdb.dbo.$(DatabaseName)_backup_database_last_access') IS NULL AND OBJECT_ID(N'[$(DatabaseName)].[audit].[database_last_access]') IS NOT NULL)
	BEGIN
		SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[$(DatabaseName)_backup_database_last_access] FROM [$(DatabaseName)].[audit].[database_last_access]';
		EXEC sp_executesql @stmt=@backupsql;
	END
	
END
GO