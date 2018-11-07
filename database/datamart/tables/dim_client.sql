CREATE TABLE [datamart].[dim_client]
(
	[client_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[name] NVARCHAR(128) NOT NULL UNIQUE,
	[is_supported] BIT NOT NULL DEFAULT 1,
	[support_contact_primary] VARCHAR(500) NOT NULL DEFAULT SYSTEM_USER,
	[support_contact_secondary] VARCHAR(500) NULL, 
)