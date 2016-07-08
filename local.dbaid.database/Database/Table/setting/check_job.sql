/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[check_job]
(
	[job_id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
	[job_name] NVARCHAR(128) NOT NULL,
	[max_job_runtime_minute] SMALLINT NOT NULL,
    [check_job_state] INT NOT NULL,
	[check_job_enabled] BIT NOT NULL DEFAULT 1,
	CONSTRAINT [FK_check_job_check_job_state] FOREIGN KEY ([check_job_state]) REFERENCES [setting].[check_state]([state_id])
)