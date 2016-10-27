CREATE TABLE [checkmk].[tbl_pnp_config_capacity_fg] 
(
	[db_name] NVARCHAR(128) NOT NULL PRIMARY KEY,
	[capacity_warning_percent_free] NUMERIC(5,2) NOT NULL DEFAULT 20.00,
	[capacity_critical_percent_free] NUMERIC(5,2) NOT NULL DEFAULT 10.00, 
    [is_enabled] BIT NOT NULL DEFAULT 1
)
