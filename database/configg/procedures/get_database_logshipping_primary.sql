/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_database_logshipping_primary]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'Database' AS [group], 'Logshipping' AS [heading], 'This is a list of primary databases being logshipped' AS [comment]

	SELECT [primary_id]
      ,[primary_server]
      ,[primary_database]
      ,[backup_threshold]
      ,[threshold_alert]
      ,[threshold_alert_enabled]
      ,[history_retention_period]
	FROM [msdb].[dbo].[log_shipping_monitor_primary]
END