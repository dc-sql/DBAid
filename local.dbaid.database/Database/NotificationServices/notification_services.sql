/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE SERVICE [ServerService]
ON QUEUE [dbo].[ServerQueue]([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO

CREATE SERVICE [DatabaseService]
ON QUEUE [dbo].[DatabaseQueue]([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO

CREATE SERVICE [DeadlockService]
ON QUEUE [dbo].[DeadlockQueue]([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO

CREATE SERVICE [MirrorService]
ON QUEUE [dbo].[MirrorQueue]([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO

CREATE SERVICE [BlockService]
ON QUEUE [dbo].[BlockQueue]([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO

CREATE SERVICE [LoginService]
ON QUEUE [dbo].[LoginQueue]([http://schemas.microsoft.com/SQL/Notifications/PostEventNotification]);
GO