/*



*/

CREATE TABLE [checkmk].[config_alwayson] (
    [ag_name]                 NVARCHAR (256)   NULL,
    [ag_state_alert]          NVARCHAR (8)     NOT NULL DEFAULT 'CRITICAL',
    [ag_state_is_enabled]     BIT              NOT NULL	DEFAULT 1,
    [ag_role]                 NVARCHAR (256)   NULL,
    [ag_role_alert]           NVARCHAR (8)     NOT NULL DEFAULT 'CRITICAL',
    [ag_role_is_enabled]      BIT              NOT NULL	DEFAULT 1,
    [ag_role_change_datetime] DATETIME         NOT NULL	DEFAULT GETDATE()
	CONSTRAINT [CK_config_alwayson_state] CHECK ([ag_state_alert] = N'NA' OR [ag_state_alert] = N'OK' OR [ag_state_alert] = N'WARNING' OR [ag_state_alert] = N'CRITICAL'),
	[inventory_date] DATETIME NOT NULL DEFAULT GETDATE(), 
    CONSTRAINT [CK_config_alwayson_role] CHECK ([ag_role_alert] = N'NA' OR [ag_role_alert] = N'OK' OR [ag_role_alert] = N'WARNING' OR [ag_role_alert] = N'CRITICAL')
);

GO

CREATE TRIGGER [checkmk].[ag_role_change_datetime]
ON [checkmk].[config_alwayson]
AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

	IF (UPDATE ([ag_role]))
	BEGIN
		UPDATE [checkmk].[config_alwayson]
		SET [ag_role_change_datetime] = GETDATE()
		FROM [inserted] [i]
		WHERE [checkmk].[config_alwayson].[ag_name] = [i].[ag_name];
	END
END