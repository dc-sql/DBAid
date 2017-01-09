CREATE TABLE [checkmk].[tbl_config_backup]
(
	[db_name] SYSNAME NOT NULL PRIMARY KEY,
	[alert_full_state] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[alert_diff_state] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[alert_tran_state] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[full_frequency_hour] INT NOT NULL DEFAULT 30,
	[diff_frequency_hour] INT NOT NULL DEFAULT 30,
	[tran_frequency_minute] INT NOT NULL DEFAULT 120,
	[is_check_full_enabled] BIT NOT NULL DEFAULT 1,
	[is_check_diff_enabled] BIT NOT NULL DEFAULT 1,
	[is_check_tran_enabled] BIT NOT NULL DEFAULT 1,
    CONSTRAINT [ck_tbl_config_backup_state] 
		CHECK ([alert_full_state] IN ('WARNING','CRITICAL') 
			AND [alert_diff_state] IN ('WARNING','CRITICAL')
			AND [alert_tran_state] IN ('WARNING','CRITICAL'))
)
