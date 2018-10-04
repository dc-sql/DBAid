CREATE PROCEDURE [health].[report_dead_lock_history]
WITH ENCRYPTION
AS
BEGIN
	PRINT 'If extended event trace not exist, create deadlock XE. list deadlock history for past month.'
END
