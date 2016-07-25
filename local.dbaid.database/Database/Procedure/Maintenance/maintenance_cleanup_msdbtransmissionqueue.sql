/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [maintenance].[cleanup_msdbtransmissionqueue]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sql NCHAR(78);
	DECLARE @parameter NCHAR(53);
	DECLARE @conversation_handle UNIQUEIDENTIFIER;
	DECLARE @print_message CHAR(55)

	SET @sql = 'USE [msdb]; END CONVERSATION @con_handle WITH CLEANUP';
	SET @parameter = '@con_handle UNIQUEIDENTIFIER';

	WHILE EXISTS (SELECT TOP(1) 1 FROM [msdb].[sys].[transmission_queue] WHERE [is_end_of_dialog] = 1 OR [is_conversation_error] = 1)
	BEGIN
		SELECT TOP(1) @conversation_handle = [conversation_handle] FROM [msdb].[sys].[transmission_queue] WHERE [is_end_of_dialog] = 1 OR [is_conversation_error] = 1;
		EXEC sp_executesql @stmt = @sql, @params = @parameter, @con_handle = @conversation_handle;

		SET @print_message = 'Conversation Ended ' + CAST(@conversation_handle AS CHAR(36));
		PRINT @print_message;
	END
END