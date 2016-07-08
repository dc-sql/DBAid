/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[check_database]
(
	[database_id] INT NOT NULL PRIMARY KEY,
	[db_name] NVARCHAR(128) NOT NULL,
	[expected_mirror_role] NVARCHAR(128) NULL,
	[check_database_state] INT NOT NULL,
	[check_database_enabled] BIT NOT NULL DEFAULT 1,
	[check_mirror_state] INT NOT NULL,
	[check_mirror_enabled] BIT NOT NULL DEFAULT 1,
	[check_backup_since_hour] INT NOT NULL,
	[check_backup_state] INT NOT NULL,
    [check_integrity_since_hour] INT NOT NULL,
	[check_integrity_state] INT NOT NULL, 
	[check_capacity_warning_percent_free] TINYINT NOT NULL,
    [check_capacity_critical_percent_free] TINYINT NOT NULL,
	CONSTRAINT [FK_check_database_check_database_state] FOREIGN KEY ([check_database_state]) REFERENCES [setting].[check_state]([state_id]),
	CONSTRAINT [FK_check_database_check_mirror_state] FOREIGN KEY ([check_mirror_state]) REFERENCES [setting].[check_state]([state_id]),
	CONSTRAINT [FK_check_database_check_backup_state] FOREIGN KEY ([check_backup_state]) REFERENCES [setting].[check_state]([state_id]),
	CONSTRAINT [FK_check_database_check_integrity_state] FOREIGN KEY ([check_integrity_state]) REFERENCES [setting].[check_state]([state_id]),
)