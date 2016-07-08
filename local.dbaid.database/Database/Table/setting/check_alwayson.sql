/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[check_alwayson](
	[availability_group_id] [uniqueidentifier] NULL,
	[availability_group_name] [nvarchar](256) NULL,
	[expected_node_role] [nvarchar](256) NULL,
	[check_health_state] INT NOT NULL,
	[check_health_enabled] [bit] NOT NULL DEFAULT 1,
	[check_role_state] INT NOT NULL,
	[check_role_enabled] [bit] NOT NULL DEFAULT 1, 
    CONSTRAINT [FK_check_alwayson_health_check_state] FOREIGN KEY ([check_health_state]) REFERENCES [setting].[check_state]([state_id]),
	CONSTRAINT [FK_check_alwayson_role_check_state] FOREIGN KEY ([check_role_state]) REFERENCES [setting].[check_state]([state_id])
)
GO