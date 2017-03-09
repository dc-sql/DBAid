CREATE TABLE [checkmk].[configuration_agentjob]
(
	[job_id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	[name] SYSNAME NOT NULL,
	[check_agentjob_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[check_agentjob_runtime_min] INT NOT NULL DEFAULT 200, 
	[is_agentjob_enabled] BIT NOT NULL DEFAULT 1,
    CONSTRAINT [ck_tbl_configuration_agentjob_state] 
		CHECK ([check_agentjob_alert] IN ('WARNING','CRITICAL'))
)
