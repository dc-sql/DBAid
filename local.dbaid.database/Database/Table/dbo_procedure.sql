/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[procedure]
(
	[procedure_id] INT NOT NULL PRIMARY KEY, 
	[schema_name] NVARCHAR(128) NOT NULL, 
    [procedure_name] NVARCHAR(128) NOT NULL, 
    [description] NVARCHAR(500) NOT NULL, 
    [is_enabled] BIT NOT NULL DEFAULT 1, 
    [last_execution_datetime] DATETIME NULL 
)
