CREATE TABLE [datamart].[dim_instance]
(
	[instance_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_guid] UNIQUEIDENTIFIER NOT NULL
)
