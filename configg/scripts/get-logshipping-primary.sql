SET NOCOUNT ON;

SELECT 'HADR' AS [heading], 'Logshipping' AS [subheading], '**Primary**' AS [comment]

SELECT [primary_id]
    ,[primary_server]
    ,[primary_database]
    ,[backup_threshold]
    ,[threshold_alert]
    ,[threshold_alert_enabled]
    ,[history_retention_period]
FROM [msdb].[dbo].[log_shipping_monitor_primary]