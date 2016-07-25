CREATE TABLE [setting].[check_configuration]
(
	[object_name] NVARCHAR(128) NOT NULL, 
	[item_name] NVARCHAR(128) NOT NULL, 
	[column_name] NVARCHAR(128) NOT NULL,
	[column_value] SQL_VARIANT NULL,
	[change_alert] VARCHAR(10) NOT NULL DEFAULT 'critical',
	UNIQUE NONCLUSTERED ([object_name], [item_name], [column_name])
)
