/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [process].[stageauditlogin]
(
	@batch_size INT = 10000
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET DEADLOCK_PRIORITY HIGH;
	SET LOCK_TIMEOUT 10000;
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

	DECLARE @sqlserver TABLE ([pid] INT);
	DECLARE @message_batch TABLE ([message_id] BIGINT, [message_xml] XML);
	DECLARE @translated_set TABLE ([loginname] NVARCHAR(128),[ntdomainname] NVARCHAR(128),[ntusername] NVARCHAR(128),[hostname] NVARCHAR(128),[programname] NVARCHAR(128)
									,[initialconnectdbid] INT,[successlogindatetime] DATETIME,[faillogindatetime] DATETIME,[successlogincount] BIGINT,[faillogincount] BIGINT);

	INSERT INTO @sqlserver
		SELECT [host_process_id] AS [pid] 
		FROM sys.dm_exec_sessions
		WHERE CAST([program_name] AS CHAR(11)) = 'SQLAgent - '
			AND [host_name] = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128))
			AND [client_interface_name] = 'ODBC'
		UNION ALL
		SELECT CAST(SERVERPROPERTY('ProcessID') AS INT)

	WHILE (1=1)
	BEGIN
		BEGIN TRANSACTION;

			INSERT INTO @message_batch 
				SELECT TOP(@batch_size) [message_id],[message_xml] FROM [dbo].[stage_audit_login];

			IF (@@ROWCOUNT = 0)
			BEGIN
				ROLLBACK TRANSACTION;
				BREAK;
			END;

			WITH [AuditData]
			AS
			(
				SELECT [message_xml].value('(/EVENT_INSTANCE/LoginName)[1]','NVARCHAR(128)') AS [login_name]
					,[message_xml].value('(/EVENT_INSTANCE/NTDomainName)[1]','NVARCHAR(128)') AS [nt_domain_name]
					,[message_xml].value('(/EVENT_INSTANCE/NTUserName)[1]','NVARCHAR(128)') AS [nt_user_name]
					,[message_xml].value('(/EVENT_INSTANCE/HostName)[1]','NVARCHAR(128)') AS [host_name]
					,[message_xml].value('(/EVENT_INSTANCE/ApplicationName)[1]','NVARCHAR(128)') AS [program_name]
					,[message_xml].value('(/EVENT_INSTANCE/DatabaseID)[1]','INT') AS [initial_connect_dbid]
					,[message_xml].value('(/EVENT_INSTANCE/StartTime)[1]','DATETIME') AS [login_datetime]
					,1 AS [login_count]
					,[message_xml].value('(/EVENT_INSTANCE/Success)[1]','INT') AS [is_success]
				FROM @message_batch
				WHERE [message_xml].value('(/EVENT_INSTANCE/ClientProcessID)[1]','INT') NOT IN (SELECT [pid] FROM @sqlserver)
			)
			INSERT INTO @translated_set 
				SELECT [login_name]
					,[nt_domain_name]
					,[nt_user_name]
					,[host_name]
					,[program_name]
					,[initial_connect_dbid]
					,MAX(CASE WHEN [is_success] = 1 THEN [login_datetime] ELSE 0 END)
					,MAX(CASE WHEN [is_success] = 0 THEN [login_datetime] ELSE 0 END)
					,SUM(CASE WHEN [is_success] = 1 THEN [login_count] ELSE 0 END)
					,SUM(CASE WHEN [is_success] = 0 THEN [login_count] ELSE 0 END)
				FROM [AuditData]
				GROUP BY [login_name]
					,[nt_domain_name]
					,[nt_user_name]
					,[host_name]
					,[program_name]
					,[initial_connect_dbid]

			/* Merge Login Info */
			UPDATE [audit].[login]
				SET [last_success_login_datetime] = (CASE WHEN [successlogindatetime] IS NOT NULL THEN [successlogindatetime] ELSE [last_success_login_datetime] END)
					,[last_fail_login_datetime] = (CASE WHEN [faillogindatetime] IS NOT NULL THEN [faillogindatetime] ELSE [last_fail_login_datetime] END)
					,[success_login_count] = [success_login_count]+[successlogincount]
					,[fail_login_count] = [fail_login_count]+[faillogincount]
				FROM @translated_set
				WHERE [login_name] = [loginname]
					AND [nt_domain_name] = [ntdomainname]
					AND [nt_user_name] = [ntusername]
					AND [host_name] = [hostname]
					AND [program_name] = [programname]
					AND [initial_connect_dbid] = [initialconnectdbid]

			IF (@@ROWCOUNT = 0)
				INSERT INTO [audit].[login]([login_name],[nt_domain_name],[nt_user_name],[host_name],[program_name],[initial_connect_dbid],[last_success_login_datetime]
												,[last_fail_login_datetime],[success_login_count],[fail_login_count],[login_count_startdate])
					SELECT [loginname]
						,[ntdomainname]
						,[ntusername]
						,[hostname]
						,[programname]
						,[initialconnectdbid]
						,[successlogindatetime]
						,[faillogindatetime]
						,[successlogincount]
						,[faillogincount]
						,GETDATE()
					FROM @translated_set
		
			DELETE TOP(@batch_size) FROM [dbo].[stage_audit_login]
			FROM [dbo].[stage_audit_login] [S]
				INNER JOIN @message_batch [B]
					ON [S].[message_id] = [B].[message_id]
			
			DELETE FROM @message_batch;
			DELETE FROM @translated_set;
		COMMIT TRANSACTION;
	END
END