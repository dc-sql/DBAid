﻿CREATE TABLE [checkmk].[configuration_agentjob]
(
	[name] SYSNAME NOT NULL,

	[state_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[state_check_enabled] BIT NOT NULL DEFAULT 1,

	[runtime_check_alert] VARCHAR(10) NOT NULL DEFAULT 'WARNING',
	[runtime_check_min] INT NOT NULL DEFAULT 200, 
	[runtime_check_enabled] BIT NOT NULL DEFAULT 1,

    CONSTRAINT [ck_tbl_configuration_agentjob_state] 
		CHECK ([state_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_alert] IN ('WARNING','CRITICAL')
			AND [runtime_check_min] > 0)
)
