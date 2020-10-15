/*



*/

CREATE PROCEDURE [system].[set_default_agentjob_configuration]
WITH ENCRYPTION
AS
BEGIN
	EXEC msdb.dbo.sp_set_sqlagent_properties 
		@sqlserver_restart=1, 
		@monitor_autostart=1,
		@jobhistory_max_rows=999999, 
		@jobhistory_max_rows_per_job=20000;
END