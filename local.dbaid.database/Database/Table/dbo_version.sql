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