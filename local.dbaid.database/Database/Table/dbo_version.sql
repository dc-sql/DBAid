/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[version]
(
	[version] VARCHAR(20) NOT NULL, 
    [installer] NVARCHAR(128) NOT NULL DEFAULT ORIGINAL_LOGIN(), 
    [installdate] DATETIME NOT NULL DEFAULT GETDATE() 
)

GO

CREATE TRIGGER [dbo].[trg_stop_version_change]
ON [dbo].[version]
WITH ENCRYPTION
INSTEAD OF INSERT, UPDATE, DELETE
AS
BEGIN
	RAISERROR('Please do not modify the version table! This table is automatically updated. Regards the Wellington SQL DBA Team.',14,1) WITH LOG;
	ROLLBACK;
END;
GO