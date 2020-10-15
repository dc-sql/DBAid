/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[get_instance_ci]
(
	[instance_guid] UNIQUEIDENTIFIER NULL,
	[datetimeoffset] DATETIMEOFFSET NULL,
	[property] sysname NULL,
	[value] SQL_VARIANT NULL
)