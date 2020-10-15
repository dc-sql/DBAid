/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[dim_database]
(
	[database_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[name] NVARCHAR(128) NOT NULL,  
    CONSTRAINT [FK_dim_database_dim_instance] FOREIGN KEY ([instance_id]) REFERENCES [datamart].[dim_instance]([instance_id]), 
    CONSTRAINT [AK_dim_database_unique] UNIQUE ([instance_id], [name]),
)
