/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[errorlog]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@sanitize BIT = 0
)
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @mindate DATETIME;
	DECLARE @loop INT;
	DECLARE @lognum INT;
	DECLARE @enumerrorlogs TABLE ([archive] INT, [date] DATETIME, [file_size_byte] BIGINT);
	
	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=ISNULL([last_execution_datetime], DATEADD(DAY,-1,GETDATE())) 
		FROM [setting].[procedure_list] WHERE [procedure_id] = @@PROCID;
	END

	IF OBJECT_ID('tempdb..#__Errorlog') IS NOT NULL
		DROP TABLE #__Errorlog;

	IF OBJECT_ID('tempdb..#__SeverityError') IS NOT NULL
		DROP TABLE #__SeverityError;

	CREATE TABLE #__Errorlog ([log_date] DATETIME,[source] NVARCHAR(100),[message] NVARCHAR(MAX));
	CREATE TABLE #__SeverityError ([log_date] CHAR(29), [source] NVARCHAR(100), [message_header] NVARCHAR(MAX), [message] NVARCHAR(MAX));

	INSERT INTO @enumerrorlogs EXEC [master].[dbo].[xp_enumerrorlogs];
	SELECT @lognum = MAX([archive]) FROM @enumerrorlogs;

	IF (@end_datetime IS NULL)
		SET @end_datetime = GETDATE();

	SET @mindate = GETDATE()
	SET @loop = 0;
	/* Insert error log messages */
	WHILE (@loop <= @lognum)
	BEGIN
		INSERT INTO #__Errorlog([log_date],[source],[message])
			EXEC [master].[dbo].[xp_readerrorlog] @loop, 1, NULL, NULL, @start_datetime, @end_datetime;

		IF (@@ROWCOUNT = 0)
		BEGIN
			BREAK;
		END

		SET @loop = @loop + 1;
	END;

	;WITH ErrorSet
	AS
	(
		SELECT ROW_NUMBER() OVER(ORDER BY [E].[log_date], [E].[source]) AS [row_id]
			,[E].[log_date]
			,[E].[source]
			,[E].[message]
		FROM #__Errorlog [E]
	)
	INSERT INTO #__SeverityError
		SELECT [D1].[date] AS [log_date]
			,CASE WHEN CAST([A].[source] AS CHAR(4)) = 'spid' THEN 'spid' ELSE [A].[source] END AS [source] 
			,[A].[message] AS [message_header]
			,CASE WHEN @sanitize=0 THEN [B].[message] ELSE [M].[text] END AS [message]
		FROM ErrorSet [A]
			INNER JOIN ErrorSet [B]
				ON [A].[row_id]+1 = [B].[row_id]
			INNER JOIN [master].[sys].[messages] [M]
				ON [M].[language_id] = CAST(SERVERPROPERTY('LCID') AS INT)
					AND CAST(SUBSTRING([A].[message],8,CHARINDEX(',',[A].[message])-8) AS INT) = [M].[message_id]
			CROSS APPLY [get].[datetime_with_offset]([A].[log_date]) [D1]
		WHERE [A].[message] LIKE 'Error:%Severity:%State:%'
		ORDER BY [A].[log_date], [A].[source];

		SELECT [I].[guid] AS [instance_guid]
			,[E].[log_date]
			,[E].[source]
			,[E].[message_header]
			,[message].[string] AS [message]
		FROM #__SeverityError [E]
			CROSS APPLY [get].[clean_string]([E].[message]) [message]
			CROSS APPLY [get].[instance_guid]() [I]
		UNION ALL
		SELECT [I].[guid] AS [instance_guid]
			,[D].[date1] COLLATE database_default AS [log_date]
			,[E].[source]
			,N'Error: dbcc'
			,CASE WHEN @sanitize=0 THEN [message].[string] ELSE SUBSTRING([message].[string], CHARINDEX(' found ', [message].[string]), LEN([message].[string])) END AS [message]
		FROM #__Errorlog [E]
			CROSS APPLY [get].[clean_string]([E].[message]) [message]
			CROSS APPLY [get].[datetime_with_offset]([E].[log_date], NULL) [D]
			CROSS APPLY [get].[instance_guid]() [I]
		WHERE [message] LIKE '%found % errors and repaired % errors%'
			AND [message] NOT LIKE '%found 0 errors and repaired 0 errors%' 
		ORDER BY [log_date];

		IF (SELECT [value] FROM [setting].[static_parameters] WHERE [key] = 'PROGRAM_NAME') = PROGRAM_NAME()
			UPDATE [setting].[procedure_list] SET [last_execution_datetime] = @end_datetime WHERE [procedure_id] = @@PROCID;
END;