CREATE TABLE [wmiload].[tbl_wmi_query]
(
	[id] INT NOT NULL PRIMARY KEY IDENTITY,
	[query] VARCHAR(4000) NOT NULL,
	[is_enabled] BIT DEFAULT 1
)
