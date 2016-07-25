/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[logshipping_secondary]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [MS].[secondary_server]
		  ,[MS].[secondary_database]
		  ,[MS].[secondary_id]
		  ,[MS].[primary_server]
		  ,[MS].[primary_database]
		  ,[MS].[restore_threshold]
		  ,[MS].[threshold_alert]
		  ,[MS].[threshold_alert_enabled]
		  ,[MS].[history_retention_period]
		  ,[LS].[primary_server]
		  ,[LS].[primary_database]
		  ,[LS].[backup_source_directory]
		  ,[LS].[backup_destination_directory]
		  ,[LS].[file_retention_period]
		  ,[LS].[monitor_server]
		  ,[LS].[monitor_server_security_mode]
		  ,[LS].[user_specified_monitor]
		  ,CAST([LD].[logship_database_config] AS XML) AS [logship_database_config]
	  FROM [msdb].[dbo].[log_shipping_monitor_secondary] [MS]
		LEFT JOIN [msdb].[dbo].[log_shipping_secondary] [LS]
			ON [LS].[secondary_id] = [MS].[secondary_id]
		CROSS APPLY (SELECT(SELECT [secondary_database]
						  ,[secondary_id]
						  ,[restore_delay]
						  ,[restore_all]
						  ,[restore_mode]
						  ,[disconnect_users]
						  ,[block_size]
						  ,[buffer_count]
						  ,[max_transfer_size]
					  FROM [msdb].[dbo].[log_shipping_secondary_databases] 
						WHERE [secondary_id] = [MS].[secondary_id]
							FOR XML PATH('logship_database_config'), ROOT('table')) AS [logship_database_config]) [LD]
	  WHERE [MS].[secondary_server] = @@SERVERNAME
		ORDER BY
			[MS].[secondary_server]
			,[MS].[secondary_database]
END