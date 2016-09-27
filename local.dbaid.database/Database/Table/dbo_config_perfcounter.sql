/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[config_perfcounter]
(
	[object_name] NVARCHAR(128) NULL
	,[counter_name] NVARCHAR(128) NULL
	,[instance_name] NVARCHAR(128) NULL
	,[warning_threshold] NUMERIC(20, 2) NULL
	,[critical_threshold] NUMERIC(20, 2) NULL, 
    CONSTRAINT [CK_config_perfcounter_thresholds] CHECK (([warning_threshold] IS NULL AND [critical_threshold] IS NULL) OR ([warning_threshold] IS NOT NULL AND [critical_threshold] IS NOT NULL))
) 
GO

CREATE UNIQUE CLUSTERED INDEX [IX_NagiosPerformanceCounter_unique] ON [dbo].[config_perfcounter] ([object_name], [counter_name], [instance_name])
