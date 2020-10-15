/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[fact_errorlog_history]
(
	[fact_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[date_id] INT NOT NULL, 
	[time_id] INT NOT NULL, 
	[count] INT NOT NULL,
	[source] NVARCHAR(100) NOT NULL,
	[message_header] NVARCHAR(MAX) NOT NULL,
	[message] NVARCHAR(MAX) NOT NULL, 
    CONSTRAINT [FK_fact_errorlog_history_dim_instance] FOREIGN KEY ([instance_id]) REFERENCES [datamart].[dim_instance]([instance_id]),
	CONSTRAINT [FK_fact_errorlog_history_dim_date] FOREIGN KEY ([date_id]) REFERENCES [datamart].[dim_date]([date_id]),
	CONSTRAINT [FK_fact_errorlog_history_dim_time] FOREIGN KEY ([time_id]) REFERENCES [datamart].[dim_time]([time_id]),
)
