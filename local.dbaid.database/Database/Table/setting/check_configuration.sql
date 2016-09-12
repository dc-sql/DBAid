CREATE TABLE [setting].[check_configuration]
(
	[proc_id] INT NOT NULL,	/* Name of the check procedure */
	[config_id] INT NOT NULL,	/* Name of the check, e.g. max_runtime, state,  */
	[item_id] INT NOT NULL,		/* Name of the configuration item, e.g. job name, database name */
	[check_value] SQL_VARIANT NULL DEFAULT NULL,
	[check_change_alert] VARCHAR(10) NOT NULL DEFAULT 'critical',
	[description] VARCHAR(MAX) NULL, 
    CONSTRAINT [FK_check_configuration_procedure_list] FOREIGN KEY ([proc_id]) REFERENCES [setting].[procedure_list]([proc_id]), 
    CONSTRAINT [FK_check_configuration_configuration_list] FOREIGN KEY ([config_id]) REFERENCES [setting].[configuration_list]([config_id]), 
    CONSTRAINT [PK_check_configuration] PRIMARY KEY ([proc_id], [config_id], [item_id])
)
