/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[check_alwayson](
	[ag_id] [uniqueidentifier] NULL,
	[ag_name] [nvarchar](256) NULL,
	[ag_state_alert] [nvarchar](8) NOT NULL,
	[ag_state_is_enabled] [bit] NOT NULL DEFAULT ((1)),
	[ag_role] [nvarchar](256) NULL,
	[ag_role_alert] [nvarchar](8) NOT NULL,
	[ag_role_is_enabled] [bit] NOT NULL DEFAULT ((1)),
	CONSTRAINT [CK_config_alwayson_state] CHECK ([ag_state_alert] = N'NA' OR [ag_state_alert] = N'OK' OR [ag_state_alert] = N'WARNING' OR [ag_state_alert] = N'CRITICAL'),
	CONSTRAINT [CK_config_alwayson_role] CHECK ([ag_role_alert] = N'NA' OR [ag_role_alert] = N'OK' OR [ag_role_alert] = N'WARNING' OR [ag_role_alert] = N'CRITICAL')
)
GO