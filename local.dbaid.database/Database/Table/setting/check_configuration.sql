CREATE TABLE [setting].[check_configuration]
(
	[procedure_name] NVARCHAR(128) NOT NULL,	/* Name of the check procedure */
	[config_name] NVARCHAR(128) NOT NULL,	/* Name of the check, e.g. max_runtime, state,  */
	[ci_name] NVARCHAR(128) NOT NULL,		/* Name of the configuration item, e.g. job name, database name */
	[check_value] SQL_VARIANT NULL DEFAULT NULL,
	[check_change_alert] VARCHAR(10) NOT NULL DEFAULT 'critical',
	UNIQUE NONCLUSTERED ([procedure_name], [config_name], [ci_name])
)
