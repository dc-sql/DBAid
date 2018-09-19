CREATE TABLE [collector].[last_execution]
(
	[object_name] SYSNAME NOT NULL PRIMARY KEY, 
    [last_execution] DATETIME NOT NULL
)
