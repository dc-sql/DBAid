CREATE TABLE [checkmk].[configuration_procedure]
(
	[proc_id] INT NOT NULL PRIMARY KEY,
	[schema] VARCHAR(128) NOT NULL,
	[procedure] VARCHAR(128) NOT NULL,
	[is_enabled] BIT NOT NULL DEFAULT 1,
	[fullname] AS QUOTENAME([schema]) + '.' + QUOTENAME([procedure])
)
