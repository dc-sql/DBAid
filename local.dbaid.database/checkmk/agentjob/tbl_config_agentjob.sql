CREATE TABLE [checkmk].[tbl_config_agentjob]
(
	[job_name] SYSNAME NOT NULL PRIMARY KEY,
	[alert_status_state] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[alert_runtime_state] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[max_runtime_minutes] INT NOT NULL DEFAULT 180, 
	[is_check_status_enabled] BIT NOT NULL DEFAULT 1,
	[is_check_runtime_enabled] BIT NOT NULL DEFAULT 1,
    CONSTRAINT [ck_tbl_config_agentjob_state] 
		CHECK ([alert_status_state] IN ('WARNING','CRITICAL') 
			AND [alert_runtime_state] IN ('WARNING','CRITICAL'))
)
