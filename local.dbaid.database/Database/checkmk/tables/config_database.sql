/*



*/

CREATE TABLE [checkmk].[config_database]
(
	[name] sysname NOT NULL PRIMARY KEY,
	
	[database_check_alert] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[database_check_enabled] BIT NOT NULL DEFAULT 1,

	[backup_check_alert] VARCHAR(10) NOT NULL DEFAULT 'CRITICAL',
	[backup_check_enabled] BIT NOT NULL DEFAULT 1,
	[backup_check_full_hour] INT NULL DEFAULT 30,
	[backup_check_diff_hour] INT NULL DEFAULT 30,
	[backup_check_tran_hour] INT NULL DEFAULT 1,
	
	[integrity_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[integrity_check_hour] INT NOT NULL DEFAULT 170, 
	[integrity_check_enabled] BIT NOT NULL DEFAULT 1,

	[logshipping_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[logshipping_check_hour] INT NOT NULL DEFAULT 2, 
	[logshipping_check_enabled] BIT NOT NULL DEFAULT 1,

	[mirroring_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[mirroring_check_role] VARCHAR(10) NULL DEFAULT NULL,
	[mirroring_check_enabled] BIT NOT NULL DEFAULT 1,

	[capacity_check_warning_free] NUMERIC(5,2) NOT NULL DEFAULT 20.00,
	[capacity_check_critical_free] NUMERIC(5,2) NOT NULL DEFAULT 10.00, 
	[capacity_check_enabled] BIT NOT NULL DEFAULT 1,

	[inventory_date] DATETIME DEFAULT GETDATE() NOT NULL,

    CONSTRAINT [ck_config_database] 
		CHECK ([database_check_alert] IN ('WARNING','CRITICAL') 
			AND [backup_check_alert] IN ('WARNING','CRITICAL')
			AND [integrity_check_alert] IN ('WARNING','CRITICAL')
			AND [logshipping_check_alert] IN ('WARNING','CRITICAL')
			AND [mirroring_check_alert] IN ('WARNING','CRITICAL')
			AND [mirroring_check_role] IN (NULL,'PRIMARY','SECONDARY')
			AND [capacity_check_critical_free] <= [capacity_check_warning_free])
)
