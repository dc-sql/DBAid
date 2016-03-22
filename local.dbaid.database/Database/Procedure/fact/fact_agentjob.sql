/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [fact].[agentjob]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [job_name]
		,[job_owner]
		,[job_enabled]
		,[job_desc]
		,[step_details]
		,[notify_email_operator]
		,[notify_netsend_operator]
		,[notify_page_operator]
		,[job_created]
		,[job_modified]
		,[schedule_detail]
	FROM [info].[agentjob];
END