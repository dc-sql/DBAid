/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[fact_backup_history]
(
	[fact_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[database_id] INT NOT NULL,
	[start_date_id] INT NOT NULL,
	[start_time_id] INT NOT NULL,
	[finish_date_id] INT NOT NULL,
	[finish_time_id] INT NOT NULL,
	[type] CHAR(1) NOT NULL,
	[is_copy_only] BIT NULL,
	[software_name] NVARCHAR(128) NULL,
	[user_name] NVARCHAR(128) NULL,
	[physical_device_name] NVARCHAR(260) NULL,
	[size_mb] NUMERIC(20,2) NULL,
	[compressed_size_mb] NUMERIC(20,2) NULL,
	[compression_ratio] NUMERIC(5,2) NULL,
	[encryptor_type] NVARCHAR(32) NULL,
	[encryptor_thumbprint] VARBINARY(20) NULL,
	[is_password_protected] BIT NULL,
	[backup_check_full_hour] INT NULL,
	[backup_check_diff_hour] INT NULL,
	[backup_check_tran_hour] INT NULL,
	CONSTRAINT [FK_fact_backup_history_dim_instance] FOREIGN KEY ([instance_id]) REFERENCES [datamart].[dim_instance]([instance_id]),
	CONSTRAINT [FK_fact_backup_history_dim_date_1] FOREIGN KEY ([start_date_id]) REFERENCES [datamart].[dim_date]([date_id]),
	CONSTRAINT [FK_fact_backup_history_dim_date_2] FOREIGN KEY ([finish_date_id]) REFERENCES [datamart].[dim_date]([date_id]),
	CONSTRAINT [FK_fact_backup_history_dim_time_1] FOREIGN KEY ([start_time_id]) REFERENCES [datamart].[dim_time]([time_id]),
	CONSTRAINT [FK_fact_backup_history_dim_time_2] FOREIGN KEY ([finish_time_id]) REFERENCES [datamart].[dim_time]([time_id]),
)
