﻿CREATE TABLE [dbo].[stage_capacity]
(
	[instance_guid] NVARCHAR(36),
	[database_name] NVARCHAR(128),
	[physical_name] NVARCHAR(260),
	[logical_name] NVARCHAR(128),
	[type_desc] NVARCHAR(60),
	[used_mb] NUMERIC(20,2),
	[reserved_mb] NUMERIC(20,2),
	[drive] CHAR(1),
	[free_mb] NUMERIC(20,2),
	[capacity_mb] NUMERIC(20,2),
	[check_date]  NVARCHAR(29)
)