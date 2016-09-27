/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [system].[tbl_module]
(
	[module_id] TINYINT NOT NULL IDENTITY,  /* TINYINT limits to 255 modules */
    [module_name] VARCHAR(128) NOT NULL,  
    CONSTRAINT [PK_module_group] PRIMARY KEY ([module_id]) 
)
