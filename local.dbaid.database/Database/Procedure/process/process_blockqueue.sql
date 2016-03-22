/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [process].[blockqueue]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET DEADLOCK_PRIORITY HIGH;
	SET LOCK_TIMEOUT 10000;

	DECLARE @conversation_handle UNIQUEIDENTIFIER ;
	DECLARE @message_type NVARCHAR(256);
	DECLARE @message_body XML;

	WHILE (1=1)
	BEGIN
		BEGIN TRANSACTION;
			WAITFOR
			(
				RECEIVE TOP(1) @conversation_handle=[conversation_handle]
					,@message_type=[message_type_name]
					,@message_body=(CASE WHEN validation = 'X' THEN CAST([message_body] AS XML) ELSE NULL END)
				FROM [dbo].[BlockQueue]
			), TIMEOUT 500;

			IF (@@ROWCOUNT = 0)
			BEGIN
				ROLLBACK TRANSACTION;
				BREAK;
			END;

			IF (@message_type = 'http://schemas.microsoft.com/SQL/Notifications/EventNotification')
			BEGIN
				INSERT INTO [audit].[event]([postdate],[message_body],[event_notification]) 
					VALUES(ISNULL(@message_body.value('(/EVENT_INSTANCE/PostTime)[1]','DATETIME'),GETDATE()),@message_body,'BLOCKED_PROCESS_REPORT');
				
				IF @@ERROR <> 0
				BEGIN
					ROLLBACK TRANSACTION;
					END CONVERSATION @conversation_handle WITH CLEANUP;
					RAISERROR (N'Error processing SB queue, conversation ended.',11,1) WITH LOG;
				END
			END
			ELSE IF (@message_type='http://schemas.microsoft.com/SQL/ServiceBroker/Error' OR @message_type='http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
			BEGIN
				END CONVERSATION @conversation_handle WITH CLEANUP;
			END
		COMMIT TRANSACTION;
	END;
END;


	


