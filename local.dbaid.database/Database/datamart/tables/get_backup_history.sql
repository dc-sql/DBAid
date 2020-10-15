/*



*/

CREATE TABLE [datamart].[get_backup_history]
(
	[instance_guid] UNIQUEIDENTIFIER NULL,
	[database_name] NVARCHAR(127) NULL,
	[backup_type] CHAR(1) NULL,
	[backup_start_date] DATETIMEOFFSET NULL,
	[backup_finish_date] DATETIMEOFFSET NULL,
	[is_copy_only] BIT NULL,
	[software_name] NVARCHAR(128) NULL,
	[user_name] NVARCHAR(128) NULL,
	[physical_device_name] NVARCHAR(260) NULL,
	[backup_size_mb] NUMERIC(20,2) NULL,
	[compressed_backup_size_mb] NUMERIC(20,2) NULL,
	[compression_ratio] NUMERIC(5,2) NULL,
	[encryptor_type] NVARCHAR(32) NULL,
	[encryptor_thumbprint] VARBINARY(20) NULL,
	[is_password_protected] BIT NULL,
	[backup_check_full_hour] INT NULL,
	[backup_check_diff_hour] INT NULL,
	[backup_check_tran_hour] INT NULL
)
