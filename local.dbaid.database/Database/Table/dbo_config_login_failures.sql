/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[config_login_failures] 
(
  [name] sysname NOT NULL
  ,[failed_login_threshold] int NOT NULL
  ,[monitoring_period_minutes] int NOT NULL
  ,[login_failure_alert] sysname NOT NULL
);
GO
ALTER TABLE [dbo].[config_login_failures] 
ADD CONSTRAINT [PK_config_login_failures] PRIMARY KEY CLUSTERED ([name]);
GO
ALTER TABLE [dbo].[config_login_failures] 
ADD CONSTRAINT [DF_config_login_failures_threshold] DEFAULT ((10)) FOR [failed_login_threshold];
GO
ALTER TABLE [dbo].[config_login_failures] 
ADD CONSTRAINT [DF_config_login_failures_period] DEFAULT ((15)) FOR [monitoring_period_minutes];
GO
ALTER TABLE [dbo].[config_login_failures] 
ADD CONSTRAINT [DF_config_login_failures_alert] DEFAULT (('WARNING')) FOR [login_failure_alert];
GO

GRANT SELECT
    ON OBJECT::[dbo].[config_login_failures] TO [admin]
    AS [dbo];
GO

GRANT SELECT
    ON OBJECT::[dbo].[config_login_failures] TO [monitor]
    AS [dbo];
GO