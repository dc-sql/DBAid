CREATE TABLE [dbo].[warehouse_errorlog]
(
	[id] bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_warehouse_errorlog_id PRIMARY KEY CLUSTERED,
	[instance_guid] uniqueidentifier NOT NULL,
  [log_date] datetime2 NOT NULL,
	[source] nvarchar(100) NULL,
	[message_header] nvarchar(max) NULL,
  [message] nvarchar(max) NULL
) ON [PRIMARY];