/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [dbo].[toggle_audit_service]
	@enable_login_audit bit = NULL,
	@enable_blocked_process_audit bit = NULL,
	@enable_deadlock_audit bit = NULL,
	@enable_mirror_state_audit bit = NULL,
	@enable_server_ddl_audit bit = NULL,
	@enable_db_security_audit bit = NULL
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
/* To create the event notifications under the [sa] account, and not the executing account */
	EXECUTE AS LOGIN = '$(DatabaseName)_sa';

/* TOGGLE AUDIT LOGIN */
	IF (@enable_login_audit = 1)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'AUDIT_LOGIN')
			DROP EVENT NOTIFICATION [AUDIT_LOGIN] ON SERVER;

		CREATE EVENT NOTIFICATION [AUDIT_LOGIN] ON SERVER
			FOR AUDIT_LOGIN, AUDIT_LOGIN_FAILED
			TO SERVICE 'LoginService', 'current database';

		PRINT 'Created [AUDIT_LOGIN]'
	END
	ELSE IF (@enable_login_audit = 0)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'AUDIT_LOGIN')
		BEGIN
			DROP EVENT NOTIFICATION [AUDIT_LOGIN] ON SERVER;
			PRINT 'Dropped [AUDIT_LOGIN]'
		END
		ELSE PRINT '[AUDIT_LOGIN] Doesn''t Exist'
	END
	ELSE PRINT 'Skipping [AUDIT_LOGIN] Because Parameter is NULL'

/* TOGGLE BLOCKED PROCESS REPORT */
	IF (@enable_blocked_process_audit = 1)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'BLOCKED_PROCESS_REPORT')
			DROP EVENT NOTIFICATION [BLOCKED_PROCESS_REPORT] ON SERVER;

		CREATE EVENT NOTIFICATION [BLOCKED_PROCESS_REPORT] ON SERVER
			FOR BLOCKED_PROCESS_REPORT
			TO SERVICE 'BlockService', 'current database';

		PRINT 'Created [BLOCKED_PROCESS_REPORT]'
	END
	ELSE IF (@enable_blocked_process_audit = 0)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'BLOCKED_PROCESS_REPORT')
		BEGIN
			DROP EVENT NOTIFICATION [BLOCKED_PROCESS_REPORT] ON SERVER;
			PRINT 'Dropped [BLOCKED_PROCESS_REPORT]'
		END
		ELSE PRINT '[BLOCKED_PROCESS_REPORT] Doesn''t Exist'
	END
	ELSE PRINT 'Skipping [BLOCKED_PROCESS_REPORT] Because Parameter is NULL'

/* TOGGLE DEADLOCK GRAPH */
	IF (@enable_deadlock_audit = 1)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DEADLOCK_GRAPH')
			DROP EVENT NOTIFICATION [DEADLOCK_GRAPH] ON SERVER

		CREATE EVENT NOTIFICATION [DEADLOCK_GRAPH] ON SERVER
			FOR DEADLOCK_GRAPH
			TO SERVICE 'DeadlockService', 'current database';

		PRINT 'Created [DEADLOCK_GRAPH]'
	END
	ELSE IF (@enable_deadlock_audit = 0)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DEADLOCK_GRAPH')
		BEGIN
			DROP EVENT NOTIFICATION [DEADLOCK_GRAPH] ON SERVER
			PRINT 'Dropped [DEADLOCK_GRAPH]'
		END
		ELSE PRINT '[DEADLOCK_GRAPH] Doesn''t Exist'
	END
	ELSE PRINT 'Skipping [DEADLOCK_GRAPH] Because Parameter is NULL'

/* TOGGLE MIRROR STATE CHANGE */
	IF (@enable_mirror_state_audit = 1)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DATABASE_MIRRORING_STATE_CHANGE')
			DROP EVENT NOTIFICATION [DATABASE_MIRRORING_STATE_CHANGE] ON SERVER;

		CREATE EVENT NOTIFICATION [DATABASE_MIRRORING_STATE_CHANGE] ON SERVER
			FOR DATABASE_MIRRORING_STATE_CHANGE
			TO SERVICE 'MirrorService', 'current database';

		PRINT 'Created [DATABASE_MIRRORING_STATE_CHANGE]'
	END
	ELSE IF (@enable_mirror_state_audit = 0)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DATABASE_MIRRORING_STATE_CHANGE')
		BEGIN
			DROP EVENT NOTIFICATION [DATABASE_MIRRORING_STATE_CHANGE] ON SERVER;
			PRINT 'Dropped [DATABASE_MIRRORING_STATE_CHANGE]'
		END
		ELSE PRINT '[DATABASE_MIRRORING_STATE_CHANGE] Doesn''t Exist'
	END
	ELSE PRINT 'Skipping [DATABASE_MIRRORING_STATE_CHANGE] Because Parameter is NULL'

/* TOGGLE DDL SERVER */
	IF (@enable_server_ddl_audit = 1)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DDL_SERVER_LEVEL_EVENTS')
			DROP EVENT NOTIFICATION [DDL_SERVER_LEVEL_EVENTS] ON SERVER;

		CREATE EVENT NOTIFICATION [DDL_SERVER_LEVEL_EVENTS] ON SERVER
			FOR DDL_SERVER_LEVEL_EVENTS
			TO SERVICE 'ServerService', 'current database';
		
		PRINT 'Created [DDL_SERVER_LEVEL_EVENTS]'
	END
	ELSE IF (@enable_server_ddl_audit = 0)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DDL_SERVER_LEVEL_EVENTS')
		BEGIN
			DROP EVENT NOTIFICATION [DDL_SERVER_LEVEL_EVENTS] ON SERVER;
			PRINT 'Dropped [DDL_SERVER_LEVEL_EVENTS]'
		END
		ELSE PRINT '[DDL_SERVER_LEVEL_EVENTS] Doesn''t Exist'
	END
	ELSE PRINT 'Skipping [DDL_SERVER_LEVEL_EVENTS] Because Parameter is NULL'

/* TOGGLE DDL DATABASE SECURITY */
	IF (@enable_db_security_audit = 1)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DDL_DATABASE_SECURITY_EVENTS')
			DROP EVENT NOTIFICATION [DDL_DATABASE_SECURITY_EVENTS] ON SERVER

		CREATE EVENT NOTIFICATION [DDL_DATABASE_SECURITY_EVENTS] ON SERVER
			FOR DDL_DATABASE_SECURITY_EVENTS
			TO SERVICE 'DatabaseService', 'current database';

		PRINT 'Created [DDL_DATABASE_SECURITY_EVENTS]'
	END
	ELSE IF (@enable_db_security_audit = 0)
	BEGIN
		IF EXISTS (SELECT * FROM [master].[sys].[server_event_notifications] WHERE [name] = 'DDL_DATABASE_SECURITY_EVENTS')
		BEGIN
			DROP EVENT NOTIFICATION [DDL_DATABASE_SECURITY_EVENTS] ON SERVER
			PRINT 'Dropped [DDL_DATABASE_SECURITY_EVENTS]'
		END
		ELSE PRINT '[DDL_DATABASE_SECURITY_EVENTS] Doesn''t Exist'
	END
	ELSE PRINT 'Skipping [DDL_DATABASE_SECURITY_EVENTS] Because Parameter is NULL'

	REVERT;
	REVERT;
END