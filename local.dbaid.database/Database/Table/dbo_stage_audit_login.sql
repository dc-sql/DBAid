/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [dbo].[stage_audit_login]
(
	[message_id] BIGINT NOT NULL IDENTITY PRIMARY KEY, 
    [message_xml] XML NOT NULL
)

