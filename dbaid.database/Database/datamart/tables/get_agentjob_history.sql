/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[get_agentjob_history]
(
	[instance_guid] UNIQUEIDENTIFIER NULL, 
    [run_datetime] DATETIMEOFFSET NULL,
	[job_name] NVARCHAR(128) NULL,
	[step_id] INT NULL, 
	[step_name] NVARCHAR(128) NULL,
	[error_message] NVARCHAR(2048) NULL,
	[run_status] VARCHAR(17) NULL,
	[run_duration_sec] INT NULL
)
