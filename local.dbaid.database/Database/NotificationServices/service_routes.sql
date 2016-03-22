/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE ROUTE [ServerRoute]
WITH 
	SERVICE_NAME = N'ServerService',
	ADDRESS = N'LOCAL'
GO
CREATE ROUTE [DatabaseRoute]
WITH 
	SERVICE_NAME = N'DatabaseService',
	ADDRESS = N'LOCAL'
GO
CREATE ROUTE [DeadlockRoute]
WITH 
	SERVICE_NAME = N'DeadlockService',
	ADDRESS = N'LOCAL'
GO
CREATE ROUTE [MirrorRoute]
WITH 
	SERVICE_NAME = N'MirrorService',
	ADDRESS = N'LOCAL'
GO
CREATE ROUTE [BlockRoute]
WITH 
	SERVICE_NAME = N'BlockService',
	ADDRESS = N'LOCAL'
GO
CREATE ROUTE [LoginRoute]
WITH 
	SERVICE_NAME = N'LoginService',
	ADDRESS = N'LOCAL'
GO