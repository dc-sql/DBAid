CREATE TABLE [collector].[last_execution]
(
	[object_name] INT NOT NULL PRIMARY KEY, 
    [last_execution] DATETIME2 NOT NULL
)
