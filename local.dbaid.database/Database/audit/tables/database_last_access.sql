/*



*/

CREATE TABLE [audit].[database_last_access]
(
	[name] [nvarchar](128) NOT NULL,
	[last_access] [datetime] NULL,
	[last_server_restart] [datetime] NOT NULL,
	[first_audit_datetime] [datetime] NOT NULL DEFAULT GETDATE(),
	[last_audit_datetime] [datetime] NOT NULL DEFAULT GETDATE()
)
