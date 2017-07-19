CREATE TABLE [audit].[database_last_access]
(
	[db_name] [nvarchar](128) NOT NULL,
	[db_last_access] [datetime] NULL,
	[last_server_restart] [datetime] NOT NULL,
	[last_audit_datetime] [datetime] NOT NULL
)
