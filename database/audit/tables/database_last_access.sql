CREATE TABLE [audit].[database_last_access]
(
	[server_name] [nvarchar](128) NOT NULL,
	[db_name] [nvarchar](128) NOT NULL,
	[db_last_access] [datetime] NULL,
	[server_last_restart] [datetime] NOT NULL,
	[report_datatime] [datetime] NOT NULL
)
