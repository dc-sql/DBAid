CREATE TABLE [dbo].[warehouse_capacity_db]
(
	[id] bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_warehouse_capacity_db_id PRIMARY KEY CLUSTERED,
	[instance_guid] uniqueidentifier NOT NULL,
	[datetimeoffset] datetime2 NOT NULL,
	[database_name] sysname NOT NULL,
	[volume_mount_point] nvarchar(512) NOT NULL,
	[data_type] varchar(4) NOT NULL,
	[size_used_mb] numeric(20, 2) NOT NULL,
	[size_reserved_mb] numeric(20, 2) NOT NULL,
	[volume_available_mb] numeric(20, 2) NULL,
) ON [PRIMARY];
