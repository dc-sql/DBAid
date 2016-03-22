/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[dbaid_config]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [pivot].[GUID] AS [server_guid]
		,(SELECT TOP 1 [value] FROM [sys].[extended_properties] WHERE [name] = N'Version') AS [dbaid_version]
		,(SELECT TOP 1 [value] FROM [sys].[extended_properties] WHERE [name] = N'Installer') AS [installed_by]
		,(SELECT TOP 1 [value] FROM [sys].[extended_properties] WHERE [name] = N'Date') AS [installed_on]
		,[pivot].[PROGRAM_NAME] AS [program_name]
		,[pivot].AUDIT_EVENT_RETENTION_DAY AS [audit_event_retention_day]
		,[pivot].DEFRAG_LOG_RETENTION_DAY AS [defrag_log_retention_day]
		,[pivot].DEFAULT_CAP_WARN_PERCENT AS [default_cap_warn_percent]
		,[pivot].DEFAULT_CAP_CRIT_PERCENT AS [default_cap_crit_percent]
		,[pivot].CAPACITY_CACHE_RETENTION_MONTH AS [capacity_cache_retention_month]
		,[pivot].DEFAULT_JOB_MAX_MIN AS [default_job_max_min]
		,[pivot].DEFAULT_JOB_STATE AS [default_job_state]
		,[pivot].DEFAULT_DB_STATE AS [default_db_state]
		,[pivot].DEFAULT_ALWAYSON_STATE AS [default_alwayson_state]
		,[pivot].DEFAULT_ALWAYSON_ROLE AS [default_alwayson_role]
		,[pivot].NAGIOS_EVENTHISTORY_TIMESPAN_MIN AS [nagios_eventhistory_timespan_min]
		,[pivot].SANITIZE_DATASET AS [sanitize_dataset]
		,[pivot].PUBLIC_ENCRYPTION_KEY AS [public_encryption_key]
		,[pivot].DEFAULT_BACKUP_FREQ AS [default_backup_freq]
		,[pivot].DEFAULT_BACKUP_STATE AS [default_backup_state]
		,[pivot].DEFAULT_CHECKDB_FREQ AS [default_checkdb_freq]
		,[pivot].DEFAULT_CHECKDB_STATE AS [default_checkdb_state]
		,CAST((SELECT *	FROM [deprecated].[tbparameters] FOR XML PATH('row'), ROOT('table')) AS XML) AS [table_tbparameters]
		,CAST((SELECT *	FROM [dbo].[config_alwayson] FOR XML PATH('row'), ROOT('table')) AS XML) AS [table_config_alwayson]
		,CAST((SELECT *	FROM [dbo].[config_database] FOR XML PATH('row'), ROOT('table')) AS XML) AS [table_config_database]
		,CAST((SELECT *	FROM [dbo].[config_job] FOR XML PATH('row'), ROOT('table')) AS XML) AS [table_config_job]
		,CAST((SELECT *	FROM [dbo].[config_perfcounter] FOR XML PATH('row'), ROOT('table')) AS XML) AS [table_config_perfcounter]
	FROM (SELECT [name], [value] FROM [dbo].[static_parameters]) AS [source]
	PIVOT(
		MAX([value])
		FOR [name] IN (GUID
						,PROGRAM_NAME
						,AUDIT_EVENT_RETENTION_DAY
						,DEFRAG_LOG_RETENTION_DAY
						,DEFAULT_CAP_WARN_PERCENT
						,DEFAULT_CAP_CRIT_PERCENT
						,DEFAULT_JOB_MAX_MIN
						,DEFAULT_JOB_STATE
						,DEFAULT_DB_STATE
						,DEFAULT_ALWAYSON_STATE
						,DEFAULT_ALWAYSON_ROLE
						,NAGIOS_EVENTHISTORY_TIMESPAN_MIN
						,SANITIZE_DATASET
						,PUBLIC_ENCRYPTION_KEY
						,DEFAULT_BACKUP_FREQ
						,DEFAULT_CHECKDB_FREQ
						,CAPACITY_CACHE_RETENTION_MONTH
						,DEFAULT_CHECKDB_STATE
						,DEFAULT_BACKUP_STATE)
	) AS [pivot]
END

