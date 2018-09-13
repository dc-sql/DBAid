/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[config_alwayson](
	[ag_id] [uniqueidentifier] NULL,
	[ag_name] [nvarchar](256) NULL,
	[ag_state_alert] [nvarchar](8) NOT NULL,
	[ag_state_is_enabled] [bit] NOT NULL DEFAULT ((1)),
	[ag_role] [nvarchar](256) NULL,
	[ag_role_alert] [nvarchar](8) NOT NULL,
	[ag_role_is_enabled] [bit] NOT NULL DEFAULT ((1)),
	[ag_role_change_datetime] DATETIME NOT NULL DEFAULT GETDATE(), 
    CONSTRAINT [CK_config_alwayson_state] CHECK ([ag_state_alert] = N'NA' OR [ag_state_alert] = N'OK' OR [ag_state_alert] = N'WARNING' OR [ag_state_alert] = N'CRITICAL'),
	CONSTRAINT [CK_config_alwayson_role] CHECK ([ag_role_alert] = N'NA' OR [ag_role_alert] = N'OK' OR [ag_role_alert] = N'WARNING' OR [ag_role_alert] = N'CRITICAL')
)
GO

GRANT SELECT
    ON OBJECT::[dbo].[config_alwayson] TO [monitor]
    AS [dbo];
GO

GRANT SELECT
ON OBJECT::[dbo].[config_alwayson] TO [admin]
AS [dbo];
GO

GRANT DELETE
ON OBJECT::[dbo].[config_alwayson] TO [monitor]
AS [dbo];
GO

CREATE TRIGGER dbo.ag_role_change_datetime
ON [dbo].[config_alwayson]
AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

	IF (UPDATE ([ag_role]))
	BEGIN
		UPDATE [dbo].[config_alwayson]
		SET [ag_role_change_datetime] = GETDATE()
		FROM [inserted] [i]
		WHERE [dbo].[config_alwayson].[ag_id] = [i].[ag_id]
	END
END
GO