/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [collector].[get_errorlog_history]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@sanitize BIT = 1,
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#__Errorlog') IS NOT NULL
		DROP TABLE #__Errorlog;

	IF OBJECT_ID('tempdb..#__SeverityError') IS NOT NULL
		DROP TABLE #__SeverityError;

	DECLARE @mindate DATETIME;
	DECLARE @loop INT;
	DECLARE @lognum INT;
	DECLARE @enumerrorlogs TABLE ([archive] INT
									,[date] DATETIME
									,[file_size_byte] BIGINT);
	
	CREATE TABLE #__Errorlog ([id] BIGINT IDENTITY(1,1) PRIMARY KEY
								,[log_date] DATETIME2
								,[source] NVARCHAR(100)
								,[message] NVARCHAR(MAX));

	CREATE TABLE #__SeverityError ([id] BIGINT IDENTITY(1,1) PRIMARY KEY
									,[log_date] DATETIME2
									,[source] NVARCHAR(100)
									,[message_header] NVARCHAR(MAX)
									,[message] NVARCHAR(MAX));

	IF (@start_datetime IS NULL)
		SELECT @start_datetime=ISNULL([last_execution], DATEADD(DAY,-1,GETDATE())) 
		FROM [collector].[last_execution] 
		WHERE [object_name] = OBJECT_NAME(@@PROCID);

	INSERT INTO @enumerrorlogs 
		EXEC [master].[dbo].[xp_enumerrorlogs];
	
	SELECT @lognum = MAX([archive])
	FROM @enumerrorlogs;

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
		SELECT [A].[log_date]
			,CASE WHEN [B].[message] LIKE N'%found % errors and repaired % errors%'
					OR [B].[message] LIKE N'SQL Server has encountered%' 
					OR [B].[message] LIKE N'Error:%Severity:%State:%(Params:%)%'
				THEN N'SQL Server'
				ELSE [A].[source] END AS [source]
            ,CASE WHEN [B].[message] LIKE N'%found % errors and repaired % errors%'
					THEN N'ERROR:DBCC'
				WHEN [B].[message] LIKE N'SQL Server has encountered%' 
					THEN N'WARNING:Encountered'
				WHEN [B].[message] LIKE N'Error:%Severity:%State:%(Params:%)%'
					THEN SUBSTRING([B].[message], 0, CHARINDEX(N'.', [B].[message])+1)
				ELSE [A].[message] END AS [message_header]
			,[B].[message] AS [message]
		FROM ErrorSet [A]
			INNER JOIN ErrorSet [B]
				ON [A].[id]+1 = [B].[id]
		WHERE [A].[message] LIKE N'Error:%Severity:%State:%'
			AND [A].[message] NOT LIKE N'Error:%Severity:%State:%(Params:%)%'
			OR ([B].[message] LIKE N'%found % errors and repaired % errors%' AND [B].[message] NOT LIKE N'%found 0 errors and repaired 0 errors%')
			OR [B].[message] LIKE N'SQL Server has encountered%'
			OR [B].[message] LIKE N'Error:%Severity:%State:%(Params:%)%'
        ORDER BY [A].[id] ASC;

	SELECT [I].[instance_guid]
		,[D1].[datetimeoffset] AS [log_date]
		,[E].[source]
		,[E].[message_header]
		,[E].[message]
	FROM #__SeverityError [E]
		CROSS APPLY [system].[get_instance_guid]() [I]
		CROSS APPLY [system].[get_datetimeoffset]([E].[log_date]) [D1]
	ORDER BY [E].[id] ASC;

	IF (@update_execution_timestamp = 1)
		UPDATE [collector].[last_execution] 
		SET [last_execution] = @end_datetime 
		WHERE [object_name] = OBJECT_NAME(@@PROCID);
END;