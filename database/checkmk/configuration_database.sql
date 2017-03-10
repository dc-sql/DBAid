CREATE TABLE [checkmk].[configuration_database]
(
	[database_id] INT NOT NULL PRIMARY KEY,
	[name] SYSNAME NOT NULL,

	[database_check_alert] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[database_check_enabled] BIT NOT NULL DEFAULT 1,
	[database_check_bad_state] VARCHAR(10) NOT NULL DEFAULT '4,5,6', /* 4=Suspect, 5=Emergency, 6=Offline */

	[backup_check_alert] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[backup_check_enabled] BIT NOT NULL DEFAULT 1,
	[backup_check_full_hour] INT NOT NULL DEFAULT 30,
	[backup_check_diff_hour] INT NOT NULL DEFAULT 30,
	[backup_check_tran_hour] INT NOT NULL DEFAULT 1,
	
	[capacity_check_warning_free] NUMERIC(5,2) NOT NULL DEFAULT 20.00,
	[capacity_check_critical_free] NUMERIC(5,2) NOT NULL DEFAULT 10.00, 
	[capacity_check_enabled] BIT NOT NULL DEFAULT 1,

	
	
	

    CONSTRAINT [ck_configuration_database] 
		CHECK ([database_check_alert] IN ('WARNING','CRITICAL') 
			AND [backup_check_alert] IN ('WARNING','CRITICAL')
			AND [backup_check_full_hour] > 0
			AND [backup_check_diff_hour] > 0
			AND [backup_check_tran_hour] > 0
			AND [capacity_check_critical_free] <= [capacity_check_warning_free])
)
