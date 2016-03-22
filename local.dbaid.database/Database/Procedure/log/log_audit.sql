/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[audit]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@mark_runtime BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sanitize BIT;
	DECLARE @report_datetime DATETIME;
	DECLARE @event_retention_days INT;

	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=[last_execution_datetime] FROM [dbo].[procedure] WHERE [procedure_id] = @@PROCID;
		IF @start_datetime IS NULL SET @start_datetime=DATEADD(DAY,-1,GETDATE());
	END

	SELECT @sanitize=CAST([value] AS BIT) FROM [dbo].[static_parameters] WHERE [name]='SANITIZE_DATASET';

	SET @report_datetime = GETDATE();

	IF (@end_datetime IS NULL)
		SET @end_datetime = @report_datetime;

	BEGIN TRANSACTION
		;WITH AuditEvent
		AS
		(
			SELECT [E].[postdate] AS [order_date]
				,[D].[date1] AS [postdate]
				,[event_notification]
				,[message_body].value('(/EVENT_INSTANCE/EventType)[1]','NVARCHAR(128)') AS [event_type]
				,CASE 
					WHEN @sanitize=0 THEN [message].[string]
					ELSE 'SANITIZE_DATASET is enable.' 
				END AS [message_body]
			FROM [audit].[event] [E]
				CROSS APPLY [dbo].[cleanstring](REPLACE(REPLACE(REPLACE(CAST([message_body] AS NVARCHAR(MAX)),[message_body].value('(/EVENT_INSTANCE/PostTime)[1]','NVARCHAR(128)'),''),[message_body].value('(/EVENT_INSTANCE/SPID)[1]','NVARCHAR(128)'),''),CAST([message_body].query('(/EVENT_INSTANCE/TSQLCommand/SetOptions)[1]') AS NVARCHAR(MAX)),'')) [message]
				CROSS APPLY [dbo].[string_date_with_offset]([E].[postdate], NULL) [D]
			WHERE [postdate] BETWEEN @start_datetime AND @end_datetime
		)
		SELECT (SELECT [guid] FROM [dbo].[instanceguid]()) AS [instance_guid]
			,[postdate]
			,[event_notification]
			,[event_type]
			,[message_body]
		FROM AuditEvent
		ORDER BY [order_date];

		SELECT @event_retention_days=CAST([value] AS TINYINT) FROM [dbo].[static_parameters] WHERE [name] = 'AUDIT_EVENT_RETENTION_DAY';
		EXEC [maintenance].[cleanup_auditevent] @olderthan_day=@event_retention_days;

		IF ((SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME() OR @mark_runtime = 1)
			UPDATE [dbo].[procedure] SET [last_execution_datetime] = @end_datetime WHERE [procedure_id] = @@PROCID;

		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION;
			RETURN 1;
		END

	COMMIT TRANSACTION;
END;

