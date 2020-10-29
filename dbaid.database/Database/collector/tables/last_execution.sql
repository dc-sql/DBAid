/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [collector].[last_execution]
(
	[object_name] sysname NOT NULL PRIMARY KEY, 
    [last_execution] DATETIME NULL
)
