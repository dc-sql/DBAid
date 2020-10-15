/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[dim_instance]
(
	[instance_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_guid] UNIQUEIDENTIFIER NOT NULL, 
	[name] NVARCHAR(128) NULL,
    CONSTRAINT [AK_dim_instance_unique] UNIQUE ([instance_guid]), 
)
