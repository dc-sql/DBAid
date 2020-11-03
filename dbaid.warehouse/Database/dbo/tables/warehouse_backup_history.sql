CREATE TABLE [dbo].[warehouse_backup_history]
(
	[id] bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_warehouse_backup_history_id PRIMARY KEY CLUSTERED,
	[instance_guid] uniqueidentifier NOT NULL,
	[database_name] sysname NOT NULL,
	[backup_type] char(1) NOT NULL,
	[backup_start_date] datetime2(7) NOT NULL,
	[backup_finish_date] datetime2(7) NOT NULL,
	[is_copy_only] bit NULL,
	[software_name] nvarchar(128) NULL,
	[user_name] nvarchar(128) NULL,
	[physical_device_name] nvarchar(260) NULL,
	[backup_size_mb] numeric(20, 2) NULL,
	[compressed_backup_size_mb] numeric(20, 2) NULL,
	[compression_ratio] numeric(5, 2) NULL,
	[is_password_protected] bit NULL,
	[backup_check_full_hour] int NULL,
	[backup_check_diff_hour] int NULL,
	[backup_check_tran_hour] int NULL
) ON [PRIMARY];
