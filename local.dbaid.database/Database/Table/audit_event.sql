/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [audit].[event]
(
	[history_id] BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY,  
    [postdate] DATETIME NOT NULL, 
    [message_body] XML NOT NULL, 
    [event_notification] VARCHAR(128) NOT NULL
)

GO

CREATE INDEX [IX_EventHistory_postdate] ON [audit].[event] ([postdate])
