CREATE TABLE [datamart].[dim_instance]
(
	[instance_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_guid] UNIQUEIDENTIFIER NOT NULL, 
	[client_id] INT NULL,
	[name] NVARCHAR(128) NULL,
    CONSTRAINT [FK_dim_instance_dim_client] FOREIGN KEY ([client_id]) REFERENCES [datamart].[dim_client]([client_id]), 
    CONSTRAINT [AK_dim_instance_unique] UNIQUE ([instance_guid], [client_id], [name]), 
)
