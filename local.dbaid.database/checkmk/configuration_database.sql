CREATE TABLE [checkmk].[configuration_database]
(
	[database_id] INT NOT NULL PRIMARY KEY,
	[name] SYSNAME NOT NULL,

	[check_database_alert] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[check_backup_alert] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',

	[check_backup_full_hour] INT NOT NULL DEFAULT 30,
	[check_backup_diff_hour] INT NOT NULL DEFAULT 30,
	[check_backup_tran_hour] INT NOT NULL DEFAULT 1,

	[check_database_enabled] BIT NOT NULL DEFAULT 1,
	[check_backup_enabled] BIT NOT NULL DEFAULT 1,

    CONSTRAINT [ck_configuration_database_state] 
		CHECK ([check_database_alert] IN ('WARNING','CRITICAL') 
			AND [check_backup_alert] IN ('WARNING','CRITICAL')),
	CONSTRAINT [ck_configuration_backup_hour] 
		CHECK ([check_backup_full_hour] > 0
			AND [check_backup_diff_hour] > 0
			AND [check_backup_tran_hour] > 0)
)
