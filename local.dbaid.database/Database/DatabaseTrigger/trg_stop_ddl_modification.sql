/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TRIGGER [trg_stop_ddl_modification] 
ON DATABASE 
WITH ENCRYPTION  
	FOR DDL_TABLE_EVENTS
		,DDL_VIEW_EVENTS
		,DDL_PROCEDURE_EVENTS
		,DDL_PARTITION_FUNCTION_EVENTS
		,DDL_SCHEMA_EVENTS
		,DDL_QUEUE_EVENTS
		,DDL_ROUTE_EVENTS
		,DDL_SERVICE_EVENTS
		,CREATE_TRIGGER
		,DROP_TRIGGER
AS 
BEGIN
   RAISERROR('Please do not modify the database outside of TFS source control. Your changes will be lost during an upgrade, and may cause application issues. Regards the Wellington SQL DBA Team.',14,1) WITH LOG;
   ROLLBACK;
END;
GO
DISABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE
GO