/*



*/

CREATE TABLE [datamart].[get_capacity_db]
(
	[instance_guid] UNIQUEIDENTIFIER NULL,
	[datetimeoffset] DATETIMEOFFSET NULL,
	[database_name] NVARCHAR(128) NULL,
	[volume_mount_point] NVARCHAR(512) NULL,
	[data_type] VARCHAR(4) NULL,
	[size_used_mb] NUMERIC(20,2) NULL,
	[size_reserved_mb] NUMERIC(20,2) NULL,
	[volume_available_mb] NUMERIC(20,2) NULL
)
