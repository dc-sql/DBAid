/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[Job]
WITH ENCRYPTION
AS
SET NOCOUNT ON;

DECLARE @cmd NVARCHAR(3000)

DECLARE @name_Length INT, @step_ID_Length INT, @step_Name_Length INT,
 @message_Length INT,@status_Length INT, @servername_Length INT, @client nvarchar(128)
 
declare @job_tbl as table 
(
[Servername] nvarchar(128),
[Job_Name] nvarchar(128),
[Step_ID] INT,
[Step_Name] nvarchar(128),
[Step_Message] nvarchar(2048),
[Status] nvarchar(20),
[Date] nvarchar(10),
[Time] nvarchar(10)
)

select @client = replace(replace(replace(CAST(serverproperty('ServerName') as varchar(128))+[setting],'@','_'),'.','_'),'\','#')  from [deprecated].[tbparameters] where [parametername] = 'Client_domain'
-- List of failed job steps
insert @job_tbl
SELECT @client,sj.name AS [Job_Name], jh.step_id  AS [Step_ID], jh.step_name  AS [Step_Name], substring(jh.message,1,2048) AS [Step_Message],
  case jh.run_status
	when 0 then 'Failed'
	when 2 then 'Retry'
	when 3 then 'Cancelled'
  	else 'In progress'
  end as 'Status',
  substring(right('00000000'+ convert(varchar(8),jh.run_date),8),7,2)  +'/'+ substring(right('00000000'+  convert(varchar(8),jh.run_date),8),5,2) +'/'+ left(right('00000000'+  convert(varchar(8),jh.run_date),8),4) as 'Date',
  left(right('000000'+  convert(varchar(6),jh.run_time),6),2) +':'+ substring(right('000000'+  convert(varchar(6),jh.run_time),6),3,2) +':'+ substring(right('000000'+  convert(varchar(6),jh.run_time),6),5,2) as 'Time'
FROM msdb..sysjobhistory jh join msdb..sysjobs sj on jh.job_id = sj.job_id
WHERE jh.run_status not in (1,4) AND step_id <> 0
AND [msdb].[dbo].[agent_datetime]([jh].[run_date], [jh].[run_time]) >= DATEADD(HOUR, 6, DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0))

-- List of failed jobs if failed on the initalization step (0)
insert @job_tbl
SELECT @client,sj.name AS [Job_Name], jh.step_id  AS [Step_ID], jh.step_name AS [Step_Name], jh.message AS [Step_Message] ,
 case jh.run_status
		when 0 then 'Failed' when 2 then 'Retry' when 3 then 'Cancelled' else 'In progress' end as 'Status'
		, substring(right('00000000'+ convert(varchar(8),jh.run_date),8),7,2)  +'/'+ substring(right('00000000'+  convert(varchar(8),jh.run_date),8),5,2) +'/'+ left(right('00000000'+  convert(varchar(8),jh.run_date),8),4) as 'Date'
		, left(right('000000'+  convert(varchar(6),jh.run_time),6),2) +':'+ substring(right('000000'+  convert(varchar(6),jh.run_time),6),3,2) +':'+ substring(right('000000'+  convert(varchar(6),jh.run_time),6),5,2) as 'Time'
		FROM msdb..sysjobhistory jh join msdb..sysjobs sj on jh.job_id = sj.job_id
		left outer join  @job_tbl jt on (sj.name = jt.[Job_Name] COLLATE database_default) 
		WHERE jh.run_status <> 1
		AND jh.step_id = 0
		and jt.[Job_Name] is null
		AND [msdb].[dbo].[agent_datetime]([jh].[run_date], [jh].[run_time]) >= DATEADD(HOUR, 6, DATEADD(DAY, DATEDIFF(DAY, 0, DATEADD(DAY,-1,GETDATE())),0))

--check to see if there are any jobs to report.
IF (select count(1) from @job_tbl) = 0 
 begin
  	--Print 'Postive check.'
	Insert @job_tbl ([Servername],[Job_Name],[Step_ID],[Step_Name],[Step_Message],[Status],[Date],[Time])
	Values(@client,'',0,'','There are no failed jobs','',CONVERT(VARCHAR(10), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0),103), CONVERT(VARCHAR(8), GETDATE(), 108))
END

Select [Servername] ,replace([Job_Name],'"','''') as [Job_Name] ,[Step_ID],replace([Step_Name],'"','''') ,[Status] ,[Date] ,[Time],replace(replace(replace([Step_Message],'"',''''), Char(13),'|'),char(10),'') as [Message] From @job_tbl

	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
		UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;
GO