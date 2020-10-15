/*



*/

CREATE TABLE [datamart].[fact_capacity_db]
(
	[fact_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[database_id] INT NOT NULL,
	[date_id] INT NOT NULL,
	[time_id] INT NOT NULL,
	[volume_mount_point] NVARCHAR(512) NOT NULL,
	[data_type] VARCHAR(4) NOT NULL,
	[size_used_mb] NUMERIC(20,2) NOT NULL,
	[size_reserved_mb] NUMERIC(20,2) NOT NULL,
	[volume_available_mb] NUMERIC(20,2) NULL
)
