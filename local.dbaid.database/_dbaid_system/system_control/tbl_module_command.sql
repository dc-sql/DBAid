/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [system].[tbl_module_command]
(
	[command_id] SMALLINT NOT NULL IDENTITY, /* SMALLINT limits to 32,767 commands. That equals 128 commands per module */
	[module_id] TINYINT NOT NULL,  
    [command] VARCHAR(4000) NOT NULL, 
	[last_execution_datetime] DATETIME NULL DEFAULT NULL,
	[is_procedure] BIT NOT NULL, 
    [is_enabled] BIT NOT NULL DEFAULT 1, 
    CONSTRAINT [PK_module_command] PRIMARY KEY ([command_id]), 
    CONSTRAINT [FK_module_command_module] FOREIGN KEY ([module_id]) REFERENCES [system].[tbl_module]([module_id])
)
