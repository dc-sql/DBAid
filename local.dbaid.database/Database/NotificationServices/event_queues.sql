/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE QUEUE [dbo].[ServerQueue]
    WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = [process].[serverqueue], MAX_QUEUE_READERS = 4, EXECUTE AS N'dbo');


GO
CREATE QUEUE [dbo].[DatabaseQueue]
    WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = [process].[databasequeue], MAX_QUEUE_READERS = 4, EXECUTE AS N'dbo');


GO
CREATE QUEUE [dbo].[DeadlockQueue]
    WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = [process].[deadlockqueue], MAX_QUEUE_READERS = 4, EXECUTE AS N'dbo');


GO
CREATE QUEUE [dbo].[MirrorQueue]
    WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = [process].[mirrorqueue], MAX_QUEUE_READERS = 4, EXECUTE AS N'dbo');


GO
CREATE QUEUE [dbo].[BlockQueue]
    WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = [process].[blockqueue], MAX_QUEUE_READERS = 4, EXECUTE AS N'dbo');


GO

CREATE QUEUE [dbo].[LoginQueue]
    WITH ACTIVATION (STATUS = ON, PROCEDURE_NAME = [process].[loginqueue], MAX_QUEUE_READERS = 8, EXECUTE AS N'dbo');


GO