/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [system].[configuration] (
    [key] VARCHAR(128) NOT NULL CONSTRAINT PK_configuration_key PRIMARY KEY CLUSTERED,
    [value] SQL_VARIANT NULL
);
GO