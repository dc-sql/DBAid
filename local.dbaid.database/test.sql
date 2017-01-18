/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

USE [_dbaid]
GO

EXEC [health].[running_queries];

EXEC [msdb].[dbo].[sp_start_job] @job_name = '_dbaid_config_genie';

EXEC [dbo].[foreachdb] N'SELECT ''?'' AS [foreachdb]';

EXEC [maintenance].[cleanup_history] @job_olderthan_day=92,@backup_olderthan_day=92,@cmdlog_olderthan_day=92,@dbmail_olderthan_day=92,@maintplan_olderthan_day=92

EXECUTE AS LOGIN = N'low-priv-acct-check-monitor';

EXEC [chart].[capacity];
EXEC [chart].[perfcounter];

EXEC [check].[alwayson];
EXEC [check].[database];
EXEC [check].[job];
EXEC [check].[logshipping];
EXEC [check].[longrunningjob];
EXEC [check].[mirroring];
EXEC [check].[backup];
EXEC [check].[checkdb];

EXEC [control].[chart];
EXEC [control].[check];
EXEC [control].[fact];
EXEC [control].[procedurelist];

EXEC [dbo].[insert_service] N'test/service/insert', N'property', N'value';

EXEC [maintenance].[check_config];

REVERT;
REVERT;

DISABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE;
DISABLE TRIGGER [trg_stop_staticparameter_change] ON [dbo].[static_parameters];

EXECUTE AS LOGIN = N'low-priv-acct-admin';

EXEC [dbo].[instance_tag];

EXEC [control].[chart];
EXEC [control].[check];
EXEC [control].[fact];
EXEC [control].[procedurelist];

EXEC [deprecated].[Backup];
EXEC [deprecated].[Databases];
EXEC [deprecated].[ErrorLog];
EXEC [deprecated].[Job];
EXEC [deprecated].[Version];

EXEC [fact].[agentjob];
EXEC [fact].[alwayson];
EXEC [fact].[database];
EXEC [fact].[databasefile];
EXEC [fact].[databasemail];
EXEC [fact].[dbaid_config];
EXEC [fact].[instance];
EXEC [fact].[maintenanceplan];
EXEC [fact].[mirroring];
EXEC [fact].[replication_publisher];
EXEC [fact].[replication_subscriber];
EXEC [fact].[security];
EXEC [fact].[serverobject];
EXEC [fact].[service];
EXEC [fact].[resource_governor];
EXEC [fact].[logshipping_primary];
EXEC [fact].[logshipping_secondary];
EXEC [fact].[cis_benchmark];

UPDATE [_dbaid].[dbo].[static_parameters]
SET value = 0
WHERE name = 'SANITIZE_DATASET'

EXEC [log].[backup];
EXEC [log].[error];
EXEC [log].[job];
EXEC [log].[maintenance];
EXEC [log].[capacity];

UPDATE [_dbaid].[dbo].[static_parameters]
SET value = 1
WHERE name = 'SANITIZE_DATASET'

EXEC [log].[backup];
EXEC [log].[error];
EXEC [log].[job];
EXEC [log].[maintenance];
EXEC [log].[capacity];

REVERT;
REVERT;

ENABLE TRIGGER [trg_stop_staticparameter_change] ON [dbo].[static_parameters];
ENABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE;

TRUNCATE TABLE [dbo].[service];


/**********************************************
		JOB TESTS
***********************************************/
USE [msdb]
GO

exec sp_start_job @job_name = '_dbaid_backup_system_full'

exec sp_start_job @job_name = '_dbaid_backup_user_full'

exec sp_start_job @job_name = '_dbaid_integrity_check_system'

exec sp_start_job @job_name = '_dbaid_integrity_check_user'

exec sp_start_job @job_name = '_dbaid_log_capacity'

exec sp_start_job @job_name = '_dbaid_maintenance_history'

exec sp_start_job @job_name = '_dbaid_backup_user_tran'

exec sp_start_job @job_name = '_dbaid_index_optimise_system'

exec sp_start_job @job_name = '_dbaid_index_optimise_user'
