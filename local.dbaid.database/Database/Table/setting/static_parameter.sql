/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[static_parameters] (
    [name]        NVARCHAR (128) NOT NULL,
    [value]       SQL_VARIANT    NOT NULL,
    [description] NVARCHAR (500) NOT NULL,
    UNIQUE NONCLUSTERED ([name] ASC)
);
GO