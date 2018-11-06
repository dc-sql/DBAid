CREATE TABLE [datamart].[fact_errorlog_history]
(
	[fact_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[date_id] INT NOT NULL, 
	[time_id] INT NOT NULL, 
	[count] INT NOT NULL,
	[source] NVARCHAR(100) NOT NULL,
	[message_header] NVARCHAR(MAX) NOT NULL,
	[message] NVARCHAR(MAX) NOT NULL
)
