/*
Returns errors from the SQL Server ERRORLOG's 

PARAMETERS
	INPUT
		@start_datetime DATETIME
		Datetime to start returning error rows from. NULL gets value from [collector].[last_execution]. Default NULL. 
		
		@end_datetime DATETIME
		Datetime to finish returning error rows from. NULL returns latest. Default NULL. 
		
		@sanitise BIT
		1 substitutes errorlog messages with generic sys.messages. NULL gets value from [system].[configuration]. Default NULL.

		@update_execution_timestamp BIT
		1 updates [collector].[last_execution], . Default 0.
*/

CREATE PROCEDURE [collector].[get_errorlog_history]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@sanitise BIT = NULL,
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
		,[message_id] INT
		,[message_header] NVARCHAR(MAX)
		,[message] NVARCHAR(MAX));

	IF (@sanitise IS NULL)
		SELECT @sanitise=CAST([value] AS BIT) FROM [system].[configuration] WHERE [key] = 'SANITISE_COLLECTOR_DATA';

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

	DECLARE errorcurse CURSOR FAST_FORWARD FOR SELECT [archive] FROM @enumerrorlogs ORDER BY [date] DESC;
	OPEN errorcurse;
	FETCH NEXT FROM errorcurse INTO @lognum;

	/* Insert error log messages */
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		INSERT INTO #__Errorlog([log_date],[source],[message])
			EXEC [master].[dbo].[xp_readerrorlog] @lognum, 1, NULL, NULL, @start_datetime, @end_datetime;

		IF (@@ROWCOUNT = 0)
		BEGIN
			BREAK;
		END

		FETCH NEXT FROM errorcurse INTO @lognum;
	END

	CLOSE errorcurse;
	DEALLOCATE errorcurse;

	;WITH ErrorSet
	AS
	(
		SELECT [E].[id]
			,[E].[log_date]
			,[E].[source]
			,[E].[message]
		FROM #__Errorlog [E]
	) 
	INSERT INTO #__SeverityError([log_date],[source],[message_id],[message_header],[message])
		SELECT [A].[log_date]
			,[source] = CASE 
				WHEN [B].[message] LIKE N'%found % errors and repaired % errors%'
					OR [B].[message] LIKE N'SQL Server has encountered%' 
					OR [B].[message] LIKE N'Error:%Severity:%State:%(Params:%)%'
					THEN N'SQL Server'
				ELSE [A].[source] END
			,[message_id] = CASE 
				WHEN [A].[message] LIKE N'Error:%Severity:%State:%' 
				THEN CAST(SUBSTRING([A].[message],8,CHARINDEX(',',[A].[message])-8) AS INT)
				ELSE NULL END
			,[message_header] = CASE 
				WHEN [B].[message] LIKE N'%found % errors and repaired % errors%' 
					THEN N'ERROR:DBCC'
				WHEN [B].[message] LIKE N'SQL Server has encountered%' 
					THEN N'WARNING:Encountered'
				WHEN [B].[message] LIKE N'Error:%Severity:%State:%(Params:%)%' 
					THEN SUBSTRING([B].[message], 0, CHARINDEX(N'.', [B].[message])+1)
				ELSE [A].[message] END
			,[B].[message] 
		FROM ErrorSet [A]
			INNER JOIN ErrorSet [B]
				ON [A].[id]+1 = [B].[id]
		WHERE [A].[message] LIKE N'Error:%Severity:%State:%'
			AND [A].[message] NOT LIKE N'Error:%Severity:%State:%(Params:%)%'
			OR ([B].[message] LIKE N'%found % errors and repaired % errors%' 
				AND [B].[message] NOT LIKE N'%found 0 errors and repaired 0 errors%')
			OR [B].[message] LIKE N'SQL Server has encountered%'
			OR [B].[message] LIKE N'Error:%Severity:%State:%(Params:%)%'
		ORDER BY [A].[id] ASC;

	SELECT [I].[instance_guid]
		,[D1].[datetimeoffset] AS [log_date]
		,[E].[source]
		,[E].[message_header]
		,CASE WHEN @sanitise = 0 THEN [E].[message] ELSE [M].[text] END AS [message]
	FROM #__SeverityError [E]
		INNER JOIN [master].[sys].[messages] [M]
			ON [M].[language_id] = CAST(SERVERPROPERTY('LCID') AS INT)
				AND [E].[message_id] = [M].[message_id]
		CROSS APPLY [system].[get_instance_guid]() [I]
		CROSS APPLY [system].[get_datetimeoffset]([E].[log_date]) [D1]
	ORDER BY [E].[log_date] ASC, [E].[id] ASC;

	IF (@update_execution_timestamp = 1)
	BEGIN
		MERGE INTO [collector].[last_execution] AS [Target]
		USING (SELECT OBJECT_NAME(@@PROCID), @end_datetime) AS [Source]([object_name],[last_execution])
		ON [Target].[object_name] = [Source].[object_name]
		WHEN MATCHED THEN
			UPDATE SET [Target].[last_execution] = [Source].[last_execution]
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT ([object_name],[last_execution]) VALUES ([Source].[object_name],[Source].[last_execution]);
	END
END;