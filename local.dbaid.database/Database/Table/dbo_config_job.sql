/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[config_job]
(
	[job_id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	[job_name] NVARCHAR(128) NOT NULL,
	[max_exec_time_min] SMALLINT NOT NULL,
    [change_state_alert] NVARCHAR(8) NOT NULL DEFAULT N'WARNING',
	[is_enabled] BIT NOT NULL DEFAULT 1,
	CONSTRAINT [CK_config_job_state] CHECK ([change_state_alert] = N'NA' OR [change_state_alert] = N'OK' OR [change_state_alert] = N'WARNING' OR [change_state_alert] = N'CRITICAL')
)