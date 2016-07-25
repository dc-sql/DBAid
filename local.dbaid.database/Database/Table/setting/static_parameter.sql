/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[static_parameters] (
    [key] VARCHAR(128) NOT NULL,
    [value] SQL_VARIANT NOT NULL,
    UNIQUE NONCLUSTERED ([key] ASC)
);
GO