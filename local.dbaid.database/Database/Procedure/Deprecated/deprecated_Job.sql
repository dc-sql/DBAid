/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Job]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @cmd NVARCHAR(3000)

	DECLARE @name_Length INT
			,@step_ID_Length INT
			,@step_Name_Length INT
			,@message_Length INT
			,@status_Length INT
			,@servername_Length INT
			,@client NVARCHAR(128);
 
	DECLARE @job_tbl AS TABLE 
		(
			[Servername] NVARCHAR(128),
			[Job_Name] NVARCHAR(128),
			[Step_ID] INT,
			[Step_Name] NVARCHAR(128),
			[Step_Message] NVARCHAR(2048),
			[Status] NVARCHAR(20),
			[Date] NVARCHAR(10),
			[Time] NVARCHAR(10)
		);

	SELECT @client = REPLACE(REPLACE(REPLACE(CAST(SERVERPROPERTY('ServerName') AS VARCHAR(128)) + [setting], '@', '_'), '.', '_'), '\', '#')
	FROM [deprecated].[tbparameters] 
	WHERE [parametername] = 'Client_domain';
	
	-- List of failed job steps
	INSERT @job_tbl
		SELECT @client
				,sj.[name] AS [Job_Name]
				,jh.[step_id] AS [Step_ID]
				,jh.[step_name] AS [Step_Name]
				,SUBSTRING(jh.[message], 1, 2048) AS [Step_Message]
				,CASE jh.[run_status]
					WHEN 0 THEN 'Failed'
					WHEN 2 THEN 'Retry'
					WHEN 3 THEN 'Cancelled'
  					ELSE 'In progress'
				END AS 'Status'
				,SUBSTRING(RIGHT('00000000' + CONVERT(VARCHAR(8), jh.[run_date]), 8), 7, 2) + '/' + SUBSTRING(RIGHT('00000000' + CONVERT(VARCHAR(8), jh.[run_date]), 8), 5, 2) + '/' + LEFT(RIGHT('00000000' + CONVERT(VARCHAR(8), jh.[run_date]), 8), 4) AS 'Date'
				,LEFT(RIGHT('000000' + CONVERT(VARCHAR(6), jh.[run_time]), 6), 2) + ':' + SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6), jh.[run_time]), 6), 3, 2) + ':' + SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6), jh.[run_time]), 6), 5, 2) AS 'Time'
		FROM [msdb].[dbo].[sysjobhistory] jh 
			JOIN [msdb].[dbo].[sysjobs] sj ON jh.[job_id] = sj.[job_id]
		WHERE jh.[run_status] NOT IN (1, 4)
		  AND step_id <> 0
		  AND [msdb].[dbo].[agent_datetime](jh.[run_date], jh.[run_time]) >= DATEADD(HOUR, 6, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0));

	-- List of failed jobs if failed on the initalization step (0)
	INSERT @job_tbl
		SELECT @client
				,sj.[name] AS [Job_Name]
				,jh.[step_id] AS [Step_ID]
				,jh.[step_name] AS [Step_Name]
				,jh.[message] AS [Step_Message]
				,CASE jh.[run_status]
					WHEN 0 THEN 'Failed' 
					WHEN 2 THEN 'Retry' 
					WHEN 3 THEN 'Cancelled' 
					ELSE 'In progress' 
				END AS 'Status'
				,SUBSTRING(RIGHT('00000000' + CONVERT(VARCHAR(8), jh.[run_date]), 8), 7, 2) + '/' + SUBSTRING(RIGHT('00000000' + CONVERT(VARCHAR(8), jh.[run_date]), 8), 5, 2) + '/' + LEFT(RIGHT('00000000' + CONVERT(VARCHAR(8), jh.[run_date]), 8), 4) AS 'Date'
				,LEFT(RIGHT('000000' + CONVERT(VARCHAR(6), jh.[run_time]), 6), 2) + ':' + SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6), jh.[run_time]), 6), 3, 2) + ':' + SUBSTRING(RIGHT('000000' + CONVERT(VARCHAR(6), jh.[run_time]), 6), 5, 2) AS 'Time'
		FROM [msdb].[dbo].[sysjobhistory] jh 
			JOIN [msdb].[dbo].[sysjobs] sj ON jh.[job_id] = sj.[job_id]
			LEFT OUTER JOIN @job_tbl jt ON (sj.[name] = jt.[Job_Name] COLLATE database_default) 
		WHERE jh.[run_status] <> 1
		  AND jh.[step_id] = 0
		  AND jt.[Job_Name] IS NULL
		  AND [msdb].[dbo].[agent_datetime]([jh].[run_date], [jh].[run_time]) >= DATEADD(HOUR, 6, DATEADD(DAY, DATEDIFF(DAY, 0, DATEADD(DAY,-1,GETDATE())),0));

	--check to see if there are any jobs to report.
	IF (SELECT COUNT(1) FROM @job_tbl) = 0 
	BEGIN
  		--Print 'Postive check.'
		INSERT @job_tbl ([Servername], [Job_Name], [Step_ID], [Step_Name], [Step_Message], [Status], [Date], [Time])
		VALUES (@client, '', 0, '', 'There are no failed jobs', '', CONVERT(VARCHAR(10), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), 103), CONVERT(VARCHAR(8), GETDATE(), 108));
	END

	SELECT [Servername] 
			,REPLACE([Job_Name], '"', '''') AS [Job_Name] 
			,[Step_ID]
			,REPLACE([Step_Name], '"', '''')
			,[Status]
			,[Date]
			,[Time]
			,REPLACE(REPLACE(REPLACE([Step_Message], '"', ''''), CHAR(13), '|'), CHAR(10), '') AS [Message] 
	FROM @job_tbl;

	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
		UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;

	REVERT;
END
GO