/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE SCHEMA [log];
GO
CREATE SCHEMA [fact];
GO
CREATE SCHEMA [check];
GO
CREATE SCHEMA [chart];
GO
CREATE SCHEMA [maintenance];
GO
CREATE SCHEMA [control];
GO
CREATE SCHEMA [info];
GO
CREATE SCHEMA [process];
GO
CREATE SCHEMA [deprecated];
GO
CREATE SCHEMA [health];
GO

GRANT EXECUTE ON SCHEMA::[log] TO [admin] AS [dbo];
GO
GRANT SELECT ON SCHEMA::[info] TO [admin] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[deprecated] TO [admin] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[control] TO [admin] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[fact] TO [admin] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[maintenance] TO [admin] AS [dbo];
GO

GRANT EXECUTE ON SCHEMA::[control] TO [monitor] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[check] TO [monitor] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[chart] TO [monitor] AS [dbo];
GO
GRANT EXECUTE ON SCHEMA::[fact] TO [monitor] AS [dbo];
GO

