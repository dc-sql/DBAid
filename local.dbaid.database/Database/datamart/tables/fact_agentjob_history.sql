/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[fact_agentjob_history]
(
	[fact_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[date_id] INT NOT NULL,
	[time_id] INT NOT NULL,
	[count] INT NOT NULL,
	[job_name] NVARCHAR(128) NOT NULL,
	[step_id] INT NOT NULL,
	[step_name] NVARCHAR(128) NOT NULL,
	[error_message] NVARCHAR(2048) NULL,
	[run_status] VARCHAR(17) NOT NULL,
	[run_duration_sec] INT NOT NULL,
	CONSTRAINT [FK_fact_agentjob_history_dim_instance] FOREIGN KEY ([instance_id]) REFERENCES [datamart].[dim_instance]([instance_id]),
	CONSTRAINT [FK_fact_agentjob_history_dim_date] FOREIGN KEY ([date_id]) REFERENCES [datamart].[dim_date]([date_id]),
	CONSTRAINT [FK_fact_agentjob_history_dim_time] FOREIGN KEY ([time_id]) REFERENCES [datamart].[dim_time]([time_id]),
)
