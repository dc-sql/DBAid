/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

SET NOEXEC OFF;
GO
USE [master];
GO

IF (DB_ID(N'_dbaid') IS NOT NULL)
BEGIN
	DECLARE @backupsql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb.dbo._dbaid_Version') IS NULL
		CREATE TABLE [tempdb].[dbo].[_dbaid_Version] ([ver] varchar(10));

	/* Allowing for upgrading from DBAid 10+ or legacy versions.
	   If legacy version, only backup some of the tables, as not all items are present in DBAid 10+ */
	IF EXISTS (SELECT 1 FROM [_dbaid].sys.tables WHERE [name] = 'version' AND [schema_id] = SCHEMA_ID('dbo'))
	BEGIN
		INSERT INTO [tempdb].[dbo].[_dbaid_Version]
		  SELECT MAX([Version]) FROM [_dbaid].[dbo].[Version];

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_alwayson') IS NULL AND OBJECT_ID(N'[_dbaid].[dbo].[config_alwayson]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT [ag_id],[ag_name],[ag_state_alert],[ag_state_is_enabled],[ag_role],[ag_role_alert],[ag_role_is_enabled] INTO [tempdb].[dbo].[_dbaid_backup_config_alwayson] FROM [_dbaid].[dbo].[config_alwayson]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_database') IS NULL AND OBJECT_ID(N'[_dbaid].[dbo].[config_database]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_config_database] FROM [_dbaid].[dbo].[config_database]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_agentjob') IS NULL AND OBJECT_ID(N'[_dbaid].[dbo].[config_job]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_config_agentjob] FROM [_dbaid].[dbo].[config_job]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_perfcounter') IS NULL AND OBJECT_ID(N'[_dbaid].[dbo].[config_perfcounter]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_config_perfcounter] FROM [_dbaid].[dbo].[config_perfcounter]';
			EXEC sp_executesql @stmt=@backupsql;
		END
	END
	ELSE
	BEGIN
	    /* Want actual version number only */
		INSERT INTO [tempdb].[dbo].[_dbaid_Version]
		  SELECT MAX(REVERSE(SUBSTRING(REVERSE([key]), CHARINDEX(REVERSE([key]), '_'), 7))) FROM [_dbaid].[system].[configuration] WHERE [key] LIKE 'DBAID_VERSION%';

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_alwayson') IS NULL AND OBJECT_ID(N'[_dbaid].[checkmk].[config_alwayson]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT [ag_id],[ag_name],[ag_state_alert],[ag_state_is_enabled],[ag_role],[ag_role_alert],[ag_role_is_enabled] INTO [tempdb].[dbo].[_dbaid_backup_config_alwayson] FROM [_dbaid].[checkmk].[config_alwayson]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_database') IS NULL AND OBJECT_ID(N'[_dbaid].[checkmk].[config_database]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_config_database] FROM [_dbaid].[checkmk].[config_database]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_agentjob') IS NULL AND OBJECT_ID(N'[_dbaid].[checkmk].[config_agentjob]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_config_agentjob] FROM [_dbaid].[checkmk].[config_agentjob]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_config_perfcounter') IS NULL AND OBJECT_ID(N'[_dbaid].[checkmk].[config_perfcounter]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_config_perfcounter] FROM [_dbaid].[checkmk].[config_perfcounter]';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_configuration') IS NULL AND OBJECT_ID(N'[_dbaid].[system].[configuration]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_configuration] FROM [_dbaid].[system].[configuration] WHERE [key] NOT IN (''PUBLIC_ENCRYPTION_KEY'')';
			EXEC sp_executesql @stmt=@backupsql;
		END

		IF (OBJECT_ID(N'tempdb.dbo._dbaid_backup_database_last_access') IS NULL AND OBJECT_ID(N'[_dbaid].[audit].[database_last_access]') IS NOT NULL)
		BEGIN
			SET @backupsql = N'SELECT * INTO [tempdb].[dbo].[_dbaid_backup_database_last_access] FROM [_dbaid].[audit].[database_last_access]';
			EXEC sp_executesql @stmt=@backupsql;
		END
	END
END
GO