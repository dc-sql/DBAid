CREATE TABLE [dbo].[warehouse_db]
(
	[id] bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_warehouse_db_id PRIMARY KEY CLUSTERED,
	[instance_guid] uniqueidentifier NOT NULL,
  [datetimeoffset] datetime2 NOT NULL,
	[database_name] sysname NOT NULL,
	[property] sysname NOT NULL,
	[value] sql_variant NULL,
) ON [PRIMARY];
