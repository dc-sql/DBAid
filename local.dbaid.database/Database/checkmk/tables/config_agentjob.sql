/*



*/

CREATE TABLE [checkmk].[config_agentjob]
(
	[name] sysname NOT NULL PRIMARY KEY,

	[state_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[state_fail_check_enabled] BIT NOT NULL DEFAULT 1,
	[state_cancel_check_enabled] BIT NOT NULL DEFAULT 0,

	[runtime_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[runtime_check_min] INT NOT NULL DEFAULT 200, 
	[runtime_check_enabled] BIT NOT NULL DEFAULT 1,

    [is_continuous_running_job] BIT NOT NULL DEFAULT 0, 
    [inventory_date] DATETIME NOT NULL DEFAULT GETDATE(), 
    CONSTRAINT [ck_tbl_config_agentjob_state] 
		CHECK ([state_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_min] > 0)
)
