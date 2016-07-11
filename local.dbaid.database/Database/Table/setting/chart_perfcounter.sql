/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [setting].[chart_perfcounter]
(
	[object_name] NVARCHAR(128) NULL
	,[counter_name] NVARCHAR(128) NULL
	,[instance_name] NVARCHAR(128) NULL
	,[check_warning_threshold] NUMERIC(20, 2) NULL DEFAULT NULL
	,[check_critical_threshold] NUMERIC(20, 2) NULL DEFAULT NULL, 
    CONSTRAINT [CK_config_perfcounter_thresholds] CHECK (([check_warning_threshold] IS NULL AND [check_critical_threshold] IS NULL) OR ([check_warning_threshold] IS NOT NULL AND [check_critical_threshold] IS NOT NULL))
) 
GO

CREATE UNIQUE CLUSTERED INDEX [ix_performance_counter_1_2_3_unique] ON [setting].[chart_perfcounter] ([object_name], [counter_name], [instance_name])
