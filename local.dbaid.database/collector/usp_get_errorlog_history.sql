/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [collector].[usp_get_errorlog_history]
(
	@start_datetime DATETIME2 = NULL,
	@end_datetime DATETIME2 = NULL,
	@sanitize BIT = 0,
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION, EXECUTE AS 'dbo'
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
		SELECT @start_datetime=ISNULL([last_execution], DATEADD(DAY,-1,SYSDATETIME())) 
		FROM [collector].[tbl_execution_timestamp] 
		WHERE [object_name] = OBJECT_NAME(@@PROCID);

	INSERT INTO @enumerrorlogs 
		EXEC [master].[dbo].[xp_enumerrorlogs];
	
	SELECT @lognum = MAX([archive])
	FROM @enumerrorlogs;

	IF (@end_datetime IS NULL)
		SET @end_datetime = SYSDATETIME();

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
			,CASE WHEN [BMSG].[clean_string] LIKE '%found % errors and repaired % errors%'
				THEN N'DBCC'
				WHEN [BMSG].[clean_string] LIKE 'SQL Server has encountered%' 
				THEN N'SQL'
				ELSE [A].[source] 
				END AS [source]
			,CASE WHEN [BMSG].[clean_string] LIKE '%found % errors and repaired % errors%'
				THEN N'ERROR'
				WHEN [BMSG].[clean_string] LIKE 'SQL Server has encountered%' 
				THEN N'WARNING'
				ELSE [AMSG].[clean_string] 
				END AS [message_header]
			,CASE WHEN @sanitize=0 
				THEN [BMSG].[clean_string] 
				ELSE [M].[text] 
				END AS [message]
		FROM ErrorSet [A]
			INNER JOIN ErrorSet [B]
				ON [A].[id]+1 = [B].[id]
			INNER JOIN [master].[sys].[messages] [M]
				ON [M].[language_id] = CAST(SERVERPROPERTY('LCID') AS INT)
					AND CAST(SUBSTRING([A].[message],8,CHARINDEX(',',[A].[message])-8) AS INT) = [M].[message_id]
			CROSS APPLY [system].[udf_get_clean_string]([A].[message]) [AMSG]
			CROSS APPLY [system].[udf_get_clean_string]([B].[message]) [BMSG]
		WHERE [A].[message] LIKE 'Error:%Severity:%State:%'
			OR ([B].[message] LIKE '%found % errors and repaired % errors%' 
				AND [B].[message] NOT LIKE '%found 0 errors and repaired 0 errors%')
			OR [B].[message] LIKE 'SQL Server has encountered%'
		ORDER BY [A].[id] ASC;
	
	SELECT [I].[instance_guid]
		,[D1].[datetimeoffset] AS [log_date]
		,[E].[source]
		,[E].[message_header]
		,[E].[message]
	FROM #__SeverityError [E]
		CROSS APPLY [system].[udf_get_instance_guid]() [I]
		CROSS APPLY [system].[udf_get_datetimeoffset]([E].[log_date]) [D1]
	ORDER BY [E].[id] ASC;

	IF (@update_execution_timestamp = 1)
		UPDATE [collector].[tbl_execution_timestamp] 
		SET [last_execution] = @end_datetime 
		WHERE [object_name] = OBJECT_NAME(@@PROCID);
END;