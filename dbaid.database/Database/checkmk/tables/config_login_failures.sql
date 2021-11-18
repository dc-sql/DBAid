CREATE TABLE [checkmk].[config_login_failures]
(
	[name] SYSNAME NOT NULL CONSTRAINT PK_config_login_failures PRIMARY KEY CLUSTERED, 
    [failed_login_threshold] INT NOT NULL CONSTRAINT [DF_config_login_failures_threshold] DEFAULT ((10)), 
    [monitoring_period_minutes] INT NOT NULL CONSTRAINT [DF_config_login_failures_period] DEFAULT ((15)), 
    [login_failure_alert] SYSNAME NULL CONSTRAINT [DF_config_login_failures_alert] DEFAULT (('WARNING'))
)
