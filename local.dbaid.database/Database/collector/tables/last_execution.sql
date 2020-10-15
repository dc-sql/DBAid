/*



*/

CREATE TABLE [collector].[last_execution]
(
	[object_name] sysname NOT NULL PRIMARY KEY, 
    [last_execution] DATETIME NULL
)
