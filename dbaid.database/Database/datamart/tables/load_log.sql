/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[load_log]
(
	[load_date] DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	[load_type] NVARCHAR(512) NOT NULL,
)
