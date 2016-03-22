/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[error]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@mark_runtime BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @sanitize BIT;
	DECLARE @mindate DATETIME;
	DECLARE @loop INT;
	DECLARE @lognum INT;
	DECLARE @enumerrorlogs TABLE ([archive] INT, [date] DATETIME, [file_size_byte] BIGINT);
	DECLARE @report_datetime DATETIME;

	SELECT @sanitize=CAST([value] AS BIT) FROM [dbo].[static_parameters] WHERE [name]='SANITIZE_DATASET';
	
	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=[last_execution_datetime] FROM [dbo].[procedure] WHERE [procedure_id] = @@PROCID;
		IF @start_datetime IS NULL SET @start_datetime=DATEADD(DAY,-1,GETDATE());
	END

	IF OBJECT_ID('tempdb..#__Errorlog') IS NOT NULL
		DROP TABLE #__Errorlog;

	IF OBJECT_ID('tempdb..#__SeverityError') IS NOT NULL
		DROP TABLE #__SeverityError;

	CREATE TABLE #__Errorlog ([log_date] DATETIME,[source] NVARCHAR(100),[message] NVARCHAR(MAX));
	CREATE TABLE #__SeverityError ([log_date] CHAR(29), [source] NVARCHAR(100), [message_header] NVARCHAR(MAX), [message] NVARCHAR(MAX));

	INSERT INTO @enumerrorlogs EXEC [master].[dbo].[xp_enumerrorlogs];
	SELECT @lognum = MAX([archive]) FROM @enumerrorlogs;

	SET @report_datetime = GETDATE();

	IF (@end_datetime IS NULL)
		SET @end_datetime = @report_datetime;

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
		SELECT [D].[date1] AS [log_date]
			,CASE WHEN CAST([A].[source] AS CHAR(4)) = 'spid' THEN 'spid' ELSE [A].[source] END AS [source] 
			,[A].[message] AS [message_header]
			,CASE WHEN @sanitize=0 THEN [B].[message] ELSE [M].[text] END AS [message]
		FROM ErrorSet [A]
			INNER JOIN ErrorSet [B]
				ON [A].[row_id]+1 = [B].[row_id]
			INNER JOIN [master].[sys].[messages] [M]
				ON [M].[language_id] = CAST(SERVERPROPERTY('LCID') AS INT)
					AND CAST(SUBSTRING([A].[message],8,CHARINDEX(',',[A].[message])-8) AS INT) = [M].[message_id]
			CROSS APPLY [dbo].[string_date_with_offset]([A].[log_date], NULL) [D]
		WHERE [A].[message] LIKE 'Error:%Severity:%State:%'
		ORDER BY [A].[log_date], [A].[source];

	BEGIN TRANSACTION
		SELECT (SELECT [guid] FROM [dbo].[instanceguid]()) AS [instance_guid]
			,[E].[log_date]
			,[E].[source]
			,[E].[message_header]
			,[message].[string] AS [message]
		FROM #__SeverityError [E]
			CROSS APPLY [dbo].[cleanstring]([E].[message]) [message]
		UNION ALL
		SELECT (SELECT [guid] FROM [dbo].[instanceguid]()) AS [instance_guid]
			,[D].[date1] COLLATE database_default AS [log_date]
			,[E].[source]
			,N'Error: dbcc'
			,CASE WHEN @sanitize=0 THEN [message].[string] ELSE SUBSTRING([message].[string], CHARINDEX(' found ', [message].[string]), LEN([message].[string])) END AS [message]
		FROM #__Errorlog [E]
			CROSS APPLY [dbo].[cleanstring]([E].[message]) [message]
			CROSS APPLY [dbo].[string_date_with_offset]([E].[log_date], NULL) [D]
		WHERE [message] LIKE '%found % errors and repaired % errors%'
			AND [message] NOT LIKE '%found 0 errors and repaired 0 errors%' 
		ORDER BY [log_date];

		IF ((SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME() OR @mark_runtime = 1)
			UPDATE [dbo].[procedure] SET [last_execution_datetime] = @end_datetime WHERE [procedure_id] = @@PROCID;

		IF (@@ERROR <> 0)
		BEGIN
			ROLLBACK TRANSACTION;
			RETURN 1;
		END
	COMMIT TRANSACTION;
END;