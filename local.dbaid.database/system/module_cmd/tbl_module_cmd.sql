/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [system].[tbl_module_cmd]
(
	[cmd_id] INT IDENTITY PRIMARY KEY,
	[module_name] VARCHAR(128) NOT NULL,
	[cmd] VARCHAR(4000) NOT NULL, 
    [is_enabled] BIT NOT NULL DEFAULT 1, 
)
