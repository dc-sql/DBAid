/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [system].[configuration] (
    [key] VARCHAR(128) NOT NULL,
    [value] SQL_VARIANT NULL,
    UNIQUE NONCLUSTERED ([key] ASC)
);
GO