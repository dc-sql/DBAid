/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[ErrorLog]
WITH ENCRYPTION
AS

SET NOCOUNT ON;

DECLARE @mindate DATETIME;
DECLARE @loop INT;
Declare @client varchar(128)
DECLARE @last_execute DATETIME;
DECLARE @report_datetime DATETIME;
DECLARE @enumerrorlogs TABLE ([archive] INT, [date] NVARCHAR(25), [file_size_byte] BIGINT);
DECLARE @lognum INT;

select @client = replace(replace(replace(CAST(serverproperty('ServerName') as varchar(128))+setting,'@','_'),'.','_'),'\','#')  from [deprecated].[tbparameters] where parametername = 'Client_domain'

SET @last_execute=DATEADD(day,-1,GETDATE());

--table to hold the errorlog entries
CREATE TABLE #errlog
	(
		date_time datetime,
		ProcessInfo varchar(50),
		err varchar(MAX),
		controw tinyint,
		countrow int identity(1,1)
	)

create table #errfound
	(
		date_time datetime,
		ProcessInfo varchar(50),
		message varchar(MAX),
		countrow int
	)

SET @report_datetime = GETDATE();
-- @lognum varaible for the number of errorlogs to review
INSERT INTO @enumerrorlogs EXEC [master].[dbo].[xp_enumerrorlogs];
SELECT @lognum = MAX([archive]) FROM @enumerrorlogs;

SET @mindate = GETDATE()
SET @loop = 0;

/* Insert error log messages */
	WHILE (@loop <= @lognum)
	BEGIN
		INSERT INTO #errlog(date_time, ProcessInfo, err)
			EXEC [master].[dbo].[xp_readerrorlog] @loop, 1, NULL, NULL, @last_execute, @report_datetime;

		IF (@@ROWCOUNT = 0)
		BEGIN
			BREAK;
		END

		SET @loop = @loop + 1;
	END;

--display only the entries of the day in question.
insert #errfound
select date_time,ProcessInfo, replace(replace(replace(err,',',''), Char(10),'|'),Char(13),'') as 'Message',  countrow from #errlog
where [date_time] >= @last_execute
and (err like '%error%' or err like '%failed%')
and (err not like '%found 0 errors and repaired 0 errors%' and err not like '%LOG\ERRORLOG%' and err not like '%without errors%' )
-- and err not like '%The SQL Network Interface%'
order by err

--Collect the Error message second row.
insert #errfound
Select el.date_time as 'Date',el.ProcessInfo, replace(replace(replace(el.err,',',''), Char(10),'|'),Char(13),'') as 'Message', el.countrow from #errlog el join #errfound ef on (el.countrow = ef.countrow +1 )
where ef.message like '%Error:%Severity:%State:%'
and (el.err not like '%error%'and el.err not like '%failed%') --make sure there are no duplicate rows.

--Display the errors.
if (select count(*) from #errfound) > 0
begin
	select [date_time]
		,[ProcessInfo]
		,@client AS [servername]
		,[message] 
	from #errfound
	order by [date_time] desc
end
else
  begin
--this will need to be changed as the number of columns is not correct
    SELECT GETDATE() AS [date_time]
		,'' AS 'ProcessInfo'
		,@client AS [servername]
		,'There are no error log messages' AS [message]
  end
--drop the table to tidy up
drop table #errlog
drop table #errfound

IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
			UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;
GO
