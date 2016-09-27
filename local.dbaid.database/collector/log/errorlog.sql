/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[errorlog]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@sanitize BIT = 0,
	@update_last_execution_datetime BIT = 0
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
		FROM [setting].[procedure_list] WHERE [proc_id] = @@PROCID;
	END

	IF OBJECT_ID('tempdb..#__Errorlog') IS NOT NULL
		DROP TABLE #__Errorlog;

	IF OBJECT_ID('tempdb..#__SeverityError') IS NOT NULL
		DROP TABLE #__SeverityError;

	CREATE TABLE #__Errorlog ([id] BIGINT IDENTITY(1,1) PRIMARY KEY, [log_date] DATETIME,[source] NVARCHAR(100),[message] NVARCHAR(MAX));
	CREATE TABLE #__SeverityError ([id] BIGINT IDENTITY(1,1) PRIMARY KEY, [log_date] DATETIME, [source] NVARCHAR(100), [message_header] NVARCHAR(MAX), [message] NVARCHAR(MAX));

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
		SELECT [E].[id]
			,[E].[log_date]
			,[E].[source]
			,[E].[message]
		FROM #__Errorlog [E]
	)
	INSERT INTO #__SeverityError([log_date],[source],[message_header],[message])
		SELECT [D1].[date] AS [log_date]
			,CASE WHEN [BMSG].[string] LIKE '%found % errors and repaired % errors%'
				THEN N'DBCC'
				WHEN [BMSG].[string] LIKE 'SQL Server has encountered%' 
				THEN N'SQL'
				ELSE [A].[source] END AS [source]
			,CASE WHEN [BMSG].[string] LIKE '%found % errors and repaired % errors%'
				THEN N'ERROR'
				WHEN [BMSG].[string] LIKE 'SQL Server has encountered%' 
				THEN N'WARNING'
				ELSE [AMSG].[string] END AS [message_header]
			,CASE WHEN @sanitize=0 THEN [BMSG].[string] ELSE [M].[text] END AS [message]
		FROM ErrorSet [A]
			INNER JOIN ErrorSet [B]
				ON [A].[id]+1 = [B].[id]
			INNER JOIN [master].[sys].[messages] [M]
				ON [M].[language_id] = CAST(SERVERPROPERTY('LCID') AS INT)
					AND CAST(SUBSTRING([A].[message],8,CHARINDEX(',',[A].[message])-8) AS INT) = [M].[message_id]
			CROSS APPLY [get].[clean_string]([A].[message]) [AMSG]
			CROSS APPLY [get].[clean_string]([B].[message]) [BMSG]
			CROSS APPLY [get].[datetime_with_offset]([A].[log_date]) [D1]
		WHERE [A].[message] LIKE 'Error:%Severity:%State:%'
			OR ([B].[message] LIKE '%found % errors and repaired % errors%'
				AND [B].[message] NOT LIKE '%found 0 errors and repaired 0 errors%')
			OR [B].[message] LIKE 'SQL Server has encountered%'
		ORDER BY [A].[id] ASC;
	
	SELECT [I].[guid] AS [instance_guid]
		,[E].[id]
		,[E].[log_date]
		,[E].[source]
		,[E].[message_header]
		,[E].[message]
	FROM #__SeverityError [E]
		CROSS APPLY [get].[instance_guid]() [I]
	ORDER BY [E].[id] ASC;

	IF (@update_last_execution_datetime = 1)
		UPDATE [setting].[procedure_list] SET [last_execution_datetime] = @end_datetime WHERE [proc_id] = @@PROCID;
END;