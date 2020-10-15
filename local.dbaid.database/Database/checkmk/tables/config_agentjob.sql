/*



*/

CREATE TABLE [checkmk].[config_agentjob]
(
	[name] sysname NOT NULL CONSTRAINT PK_config_agentjob PRIMARY KEY CLUSTERED,

	[state_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_agent_job_state_check_alert DEFAULT 'WARNING',
	[state_fail_check_enabled] BIT NOT NULL CONSTRAINT DF_agent_job_state_fail_check_enabled DEFAULT 1,
	[state_cancel_check_enabled] BIT NOT NULL CONSTRAINT DF_agent_job_state_cancel_check_enabled DEFAULT 0,

	[runtime_check_alert] VARCHAR(10) NOT NULL CONSTRAINT DF_agent_job_runtime_check_alert DEFAULT 'WARNING',
	[runtime_check_min] INT NOT NULL CONSTRAINT DF_agent_job_runtime_check_min DEFAULT 200, 
	[runtime_check_enabled] BIT NOT NULL CONSTRAINT DF_agent_job_runtime_check_enabled DEFAULT 1,

    [is_continuous_running_job] BIT NOT NULL CONSTRAINT DF_agent_job_is_continuous_running_job DEFAULT 0, 
    [inventory_date] DATETIME NOT NULL CONSTRAINT DF_agent_job_inventory_date DEFAULT GETDATE(), 
    CONSTRAINT [CK_config_agentjob] 
		CHECK ([state_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_min] > 0)
)
