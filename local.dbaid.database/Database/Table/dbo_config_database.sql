/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[config_database]
(
	[database_id] INT NOT NULL PRIMARY KEY,
	[db_name] NVARCHAR(128) NOT NULL,
	[capacity_warning_percent_free] TINYINT NOT NULL,
    [capacity_critical_percent_free] TINYINT NOT NULL,
	[mirroring_role] NVARCHAR(128) NULL,
	[backup_frequency_hours] INT NOT NULL DEFAULT 26,
	[backup_state_alert] NVARCHAR(8) NOT NULL DEFAULT N'WARNING',
    [checkdb_frequency_hours] INT NOT NULL DEFAULT 170,
	[checkdb_state_alert] NVARCHAR(8) NOT NULL DEFAULT N'WARNING',
    [change_state_alert] NVARCHAR(8) NOT NULL DEFAULT N'WARNING',
	[is_enabled] BIT NOT NULL DEFAULT 1, 
    CONSTRAINT [CK_config_database_state] CHECK ([change_state_alert] = N'NA' OR [change_state_alert] = N'OK' OR [change_state_alert] = N'WARNING' OR [change_state_alert] = N'CRITICAL'),
	CONSTRAINT [CK_config_backup_state] CHECK ([backup_state_alert] = N'NA' OR [backup_state_alert] = N'OK' OR [backup_state_alert] = N'WARNING' OR [backup_state_alert] = N'CRITICAL'),
	CONSTRAINT [CK_config_checkdb_state] CHECK ([checkdb_state_alert] = N'NA' OR [checkdb_state_alert] = N'OK' OR [checkdb_state_alert] = N'WARNING' OR [checkdb_state_alert] = N'CRITICAL')
)