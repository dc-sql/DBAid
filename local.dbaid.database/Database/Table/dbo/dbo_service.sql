/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[service](
	[class_object] [nvarchar](260) NULL,
	[property] [nvarchar](128) NULL,
	[value] [sql_variant] NULL, 
    [lastseen] DATETIME NOT NULL DEFAULT GETDATE()
) ON [PRIMARY];
GO
