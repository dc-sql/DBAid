/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[static_parameters] (
    [name]        NVARCHAR (128) NOT NULL,
    [value]       SQL_VARIANT    NOT NULL,
    [description] NVARCHAR (500) NOT NULL,
    UNIQUE NONCLUSTERED ([name] ASC)
);
GO

GRANT SELECT
    ON OBJECT::[dbo].[static_parameters] TO [admin]
    AS [dbo];
GO

GRANT SELECT
    ON OBJECT::[dbo].[static_parameters] TO [monitor]
    AS [dbo];
GO

CREATE TRIGGER [dbo].[trg_stop_staticparameter_change]
ON [dbo].[static_parameters]
WITH ENCRYPTION
INSTEAD OF INSERT, UPDATE, DELETE
AS
BEGIN
	RAISERROR('Please do not modify the static parameters unless you know what you are doing! Your changes may cause issues with the application. Regards the Wellington SQL DBA Team.',14,1) WITH LOG;
	ROLLBACK;
END;
GO