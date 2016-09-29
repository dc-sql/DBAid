CREATE TABLE [collector].[tbl_execution_timestamp]
(
	[object_name] INT NOT NULL PRIMARY KEY, 
    [last_execution] DATETIME2 NOT NULL
)
