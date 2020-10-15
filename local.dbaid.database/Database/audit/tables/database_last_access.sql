/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [audit].[database_last_access]
(
	[name] [nvarchar](128) NOT NULL,
	[last_access] [datetime] NULL,
	[last_server_restart] [datetime] NOT NULL,
	[first_audit_datetime] [datetime] NOT NULL DEFAULT GETDATE(),
	[last_audit_datetime] [datetime] NOT NULL DEFAULT GETDATE()
)
