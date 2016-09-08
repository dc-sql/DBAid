CREATE TABLE [setting].[wmi_service_query]
(
	[id] INT NOT NULL PRIMARY KEY IDENTITY,
	[query] VARCHAR(MAX) NOT NULL,
	[is_enabled] BIT DEFAULT 1
)
