/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[replication_publisher]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql_cmd NVARCHAR(4000);
	DECLARE @db_publication TABLE([db_name] NVARCHAR(128));
	DECLARE @db_name NVARCHAR(128);

	DECLARE @publications TABLE([publication_db] NVARCHAR(128)
								,[publication_name] NVARCHAR(128)
								,[publication_desc] NVARCHAR(255)
								,[repl_freq] NVARCHAR(255)
								,[sync_method] NVARCHAR(255)
								,[enabled_for_internet] BIT
								,[immediate_sync_ready] BIT
								,[allow_queued_tran] BIT
								,[allow_sync_tran] BIT
								,[autogen_sync_procs] BIT
								,[snapshot_in_defaultfolder] BIT
								,[alt_snapshot_folder] NVARCHAR(510)
								,[pre_snapshot_script] NVARCHAR(510)
								,[post_snapshot_script] NVARCHAR(510)
								,[compress_snapshot] BIT
								,[ftp_address] NVARCHAR(128)
								,[ftp_port] INT
								,[ftp_subdirectory] NVARCHAR(510)
								,[ftp_login] NVARCHAR(256)
								,[ftp_password] NVARCHAR(1048)
								,[allow_dts] BIT
								,[allow_anonymous] BIT
								,[centralized_conflicts] BIT
								,[conflict_retention] INT
								,[conflict_policy] NVARCHAR(255)
								,[backward_comp_level] INT
								,[independent_agent] BIT
								,[immediate_sync] BIT
								,[allow_push] BIT
								,[allow_pull] BIT
								,[retention] INT
								,[allow_subscription_copy] BIT
								,[allow_initialize_from_backup] BIT
								,[replicate_ddl] INT
								,[articles] XML
								,[subscribers] XML);

	INSERT INTO @db_publication EXEC [dbo].[foreachdb]  N'SELECT ''?'' FROM [?].[INFORMATION_SCHEMA].[TABLES] [T] INNER JOIN [sys].[databases] [D] ON ''?'' = [D].[name] WHERE [TABLE_NAME]=''syspublications''  AND [D].[is_distributor]=0';

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	WHILE (SELECT COUNT([db_name]) FROM @db_publication) > 0
	BEGIN
		SET @db_name=(SELECT TOP(1) [db_name] FROM @db_publication);

		SET @sql_cmd=N'SELECT ''' + @db_name + ''' AS [publication_db]
							,[P].[name] AS [publication_name]
							,[P].[description] AS [publicaiton_desc]
							,CASE [P].[repl_freq]
								WHEN 0 THEN N''Transactional''
								WHEN 1 THEN N''Snapshot''
								END AS [repl_freq]
							,CASE [P].[sync_method]
								WHEN 0 THEN N''Native bulk copy program utility (BCP)''
								WHEN 1 THEN N''Character BCP''
								WHEN 3 THEN N''Concurrent, which means that native BCP is used but tables are not locked during the snapshot''
								WHEN 4 THEN N''Concurrent_c, which means that character BCP is used but tables are not locked during the snapshot''
								END AS [sync_method]
							,[P].[enabled_for_internet]
							,[P].[immediate_sync_ready]
							,[P].[allow_queued_tran]
							,[P].[allow_sync_tran]
							,[P].[autogen_sync_procs]
							,[P].[snapshot_in_defaultfolder]
							,[P].[alt_snapshot_folder]
							,[P].[pre_snapshot_script]
							,[P].[post_snapshot_script]
							,[P].[compress_snapshot]
							,[P].[ftp_address]
							,[P].[ftp_port]
							,[P].[ftp_subdirectory]
							,[P].[ftp_login]
							,[P].[ftp_password]
							,[P].[allow_dts]
							,[P].[allow_anonymous]
							,[P].[centralized_conflicts]
							,[P].[conflict_retention]
							,CASE [P].[conflict_policy]
								WHEN 1 THEN N''Publisher wins the conflict''
								WHEN 2 THEN N''Subscriber wins the conflict''
								WHEN 3 THEN N''Subscription is reinitialized''
								END AS [conflict_policy]
							,[P].[backward_comp_level]
							,[P].[independent_agent]
							,[P].[immediate_sync]
							,[P].[allow_push]
							,[P].[allow_pull]
							,[P].[retention]
							,[P].[allow_subscription_copy]
							,[P].[allow_initialize_from_backup]
							,[P].[replicate_ddl]
							,CAST([A].[articles] AS XML) AS [articles]
							,CAST([B].[subscribers] AS XML) AS [subscribers]
						FROM [' + @db_name + '].[dbo].[syspublications] [P]
							CROSS APPLY (SELECT (SELECT [OB].[type_desc] AS [article_type]
														,[EX].[dest_owner]
														,[EX].[name] AS [local_object_name]
														,[EX].[dest_table] AS [dest_object_name]
														,CASE [EX].[pre_creation_cmd]
															WHEN 0 THEN N''None''
															WHEN 1 THEN N''Drop''
															WHEN 2 THEN N''Delete''
															WHEN 3 THEN N''Truncate''
															END AS [pre_creation_cmd]
														,[filter_clause]
														,[ins_cmd]
														,[upd_cmd]
														,[del_cmd]
														,[ins_scripting_proc]
														,[upd_scripting_proc]
														,[del_scripting_proc]
														,[custom_script]
														,[fire_triggers_on_snapshot]
													FROM [' + @db_name + '].[dbo].[sysextendedarticlesview] [EX]
														INNER JOIN [' + @db_name + '].[sys].[all_objects] [OB]
															ON [EX].[objid] = [OB].[object_id]
													FOR XML PATH(''article''), ROOT(''table'')) AS [articles]) [A]
							CROSS APPLY (SELECT (SELECT DISTINCT [srvname] AS [dest_server] 
												,[dest_db]
												,[login_name]
												,CASE [subscription_type]
													WHEN 0 THEN N''Push''
													WHEN 1 THEN N''Pull''
													END AS [subscription_type]
											FROM [' + @db_name + '].[dbo].[syssubscriptions]
											WHERE [srvid] >= 0
											FOR XML PATH(''subscriber'')) AS [subscribers]) [B]';
		
		INSERT INTO @publications
			EXEC sp_executesql @stmt = @sql_cmd;

		DELETE FROM @db_publication WHERE [db_name] = @db_name;
	END

	REVERT;
	REVERT;

	SELECT * FROM @publications;
END