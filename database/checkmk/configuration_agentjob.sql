CREATE TABLE [checkmk].[configuration_agentjob]
(
	[job_id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	[name] SYSNAME NOT NULL,

	[outcome_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[outcome_check_enabled] BIT NOT NULL DEFAULT 1,

	[runtime_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[runtime_check_min] INT NOT NULL DEFAULT 200, 
	[runtime_check_enabled] BIT NOT NULL DEFAULT 1,

    CONSTRAINT [ck_tbl_configuration_agentjob_state] 
		CHECK ([outcome_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_min] > 0)
)
