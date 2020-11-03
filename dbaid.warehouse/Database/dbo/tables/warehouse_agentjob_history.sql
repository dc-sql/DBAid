CREATE TABLE [dbo].[warehouse_agentjob_history]
(
	[id] bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_warehouse_agentjob_history_id PRIMARY KEY CLUSTERED,
	[instance_guid] uniqueidentifier NOT NULL,
  [run_datetime] datetime2 NULL,
	[job_name] sysname NOT NULL,
	[step_id] int NULL,
  [step_name] sysname NULL,
  [error_message] nvarchar(2048) NULL,
  [run_status] varchar(17) NULL,
  [run_duration_sec] int NULL
) ON [PRIMARY];
