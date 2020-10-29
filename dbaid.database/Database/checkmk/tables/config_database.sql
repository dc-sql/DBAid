/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [checkmk].[config_database]
(
	[name] sysname NOT NULL CONSTRAINT PK_config_database PRIMARY KEY CLUSTERED,
	
	[database_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_config_database_database_check_alert DEFAULT 'CRITICAL',
	[database_check_enabled] BIT NOT NULL CONSTRAINT DF_config_database_database_check_enabled DEFAULT 1,

	[backup_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_config_database_backup_check_alert DEFAULT 'WARNING',
	[backup_check_enabled] BIT NOT NULL CONSTRAINT DF_config_database_backup_check_enabled DEFAULT 1,
	[backup_check_full_hour] INT NULL CONSTRAINT DF_config_database_backup_check_full_hour DEFAULT 30,
	[backup_check_diff_hour] INT NULL CONSTRAINT DF_config_database_backup_check_diff_hour DEFAULT 30,
	[backup_check_tran_hour] INT NULL CONSTRAINT DF_config_database_backup_check_tran_hour DEFAULT 1,
	
	[integrity_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_config_database_integrity_check_alert DEFAULT 'WARNING',
	[integrity_check_hour] INT NOT NULL CONSTRAINT DF_config_database_integrity_check_hour DEFAULT 170, 
	[integrity_check_enabled] BIT NOT NULL CONSTRAINT DF_config_database_integrity_check_enabled DEFAULT 1,

	[logshipping_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_config_database_logshipping_check_alert DEFAULT 'WARNING',
	[logshipping_check_hour] INT NOT NULL CONSTRAINT DF_config_database_logshipping_check_hour DEFAULT 2, 
	[logshipping_check_enabled] BIT NOT NULL CONSTRAINT DF_config_database_logshipping_check_enabled DEFAULT 1,

	[mirroring_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_config_database_mirroring_check_alert DEFAULT 'WARNING',
	[mirroring_check_role] VARCHAR(10) NULL CONSTRAINT DF_config_database_mirroring_check_role DEFAULT NULL,
	[mirroring_check_enabled] BIT NOT NULL CONSTRAINT DF_config_database_mirroring_check_enabled DEFAULT 1,

	[capacity_check_warning_free] NUMERIC(5,2) NOT NULL CONSTRAINT DF_config_database_capacity_check_warning_free DEFAULT 20.00,
	[capacity_check_critical_free] NUMERIC(5,2) NOT NULL CONSTRAINT DF_config_database_capacity_check_critical_free DEFAULT 10.00, 
	[capacity_check_enabled] BIT NOT NULL CONSTRAINT DF_config_database_capacity_check_enabled DEFAULT 1,

	[inventory_date] DATETIME CONSTRAINT DF_config_database_inventory_date DEFAULT GETDATE() NOT NULL,

    CONSTRAINT [CK_config_database] 
		CHECK ([database_check_alert] IN ('OK','WARNING','CRITICAL') 
			AND [backup_check_alert] IN ('OK','WARNING','CRITICAL')
			AND [integrity_check_alert] IN ('OK','WARNING','CRITICAL')
			AND [logshipping_check_alert] IN ('OK','WARNING','CRITICAL')
			AND [mirroring_check_alert] IN ('OK','WARNING','CRITICAL')
			AND [mirroring_check_role] IN (NULL,'PRIMARY','SECONDARY')
			AND [capacity_check_critical_free] <= [capacity_check_warning_free])
)
