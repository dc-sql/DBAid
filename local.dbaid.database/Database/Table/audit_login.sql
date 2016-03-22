/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [audit].[login]
(
	[login_name] NVARCHAR(128) NOT NULL
	,[nt_domain_name] NVARCHAR(128)
	,[nt_user_name] NVARCHAR(128)
	,[host_name] NVARCHAR(128) NOT NULL
	,[program_name] NVARCHAR(128) NOT NULL
	,[initial_connect_dbid] NVARCHAR(128) NOT NULL
	,[last_success_login_datetime] DATETIME NULL
	,[last_fail_login_datetime] DATETIME NULL
	,[success_login_count] BIGINT NOT NULL DEFAULT 0
	,[fail_login_count] BIGINT NOT NULL DEFAULT 0
	,[login_count_startdate] DATETIME NOT NULL DEFAULT GETDATE()
)
