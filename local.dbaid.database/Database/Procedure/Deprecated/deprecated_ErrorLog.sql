/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [deprecated].[ErrorLog]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

	DECLARE @mindate DATETIME;
	Declare @client VARCHAR(128)
	DECLARE @last_execute DATETIME;
	DECLARE @report_datetime DATETIME;
	DECLARE @enumerrorlogs TABLE ([archive] INT, [date] NVARCHAR(25), [file_size_byte] BIGINT);
	DECLARE @lognum INT;

	SELECT @client = REPLACE(REPLACE(REPLACE(CAST(SERVERPROPERTY('ServerName') AS VARCHAR(128)) + setting, '@', '_'), '.', '_'), '\', '#')  
	FROM [deprecated].[tbparameters] 
	WHERE parametername = 'Client_domain';

	SET @last_execute = DATEADD(day,-1,GETDATE());

	--table to hold the errorlog entries
	CREATE TABLE #errlog
		(
			[date_time] DATETIME,
			[ProcessInfo] VARCHAR(50),
			[err] VARCHAR(MAX),
			[controw] TINYINT,
			[countrow] INT IDENTITY(1,1)
		);

	CREATE TABLE #errfound
		(
			[date_time] DATETIME,
			[ProcessInfo] VARCHAR(50),
			[message] VARCHAR(MAX),
			[countrow] INT
		);

	SET @report_datetime = GETDATE();

	-- @lognum variable for the number of errorlogs to review
	INSERT INTO @enumerrorlogs 
		EXEC [master].[dbo].[xp_enumerrorlogs];

	SET @mindate = GETDATE();

	/* Insert error log messages */
	DECLARE curse CURSOR FAST_FORWARD FOR SELECT [archive] FROM @enumerrorlogs ORDER BY [date] DESC;
	OPEN curse;
	FETCH NEXT FROM curse INTO @lognum;

		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			INSERT INTO #errlog([date_time], [ProcessInfo], [err])
				EXEC [master].[dbo].[xp_readerrorlog] @lognum, 1, NULL, NULL, @last_execute, @report_datetime;

			IF (@@ROWCOUNT = 0)
			BEGIN
				BREAK;
			END

			FETCH NEXT FROM curse INTO @lognum;
		END;

	CLOSE curse;
	DEALLOCATE curse;

	--display only the entries of the day in question.
	INSERT #errfound
		SELECT [date_time]
				,[ProcessInfo]
				,REPLACE(REPLACE(REPLACE([err],',',''), CHAR(10),'|'), CHAR(13),'') AS 'Message'
				,[countrow]
		FROM #errlog
		WHERE [date_time] >= @last_execute
		  AND ([err] LIKE '%error%' OR [err] LIKE '%failed%')
		  AND ([err] NOT LIKE '%found 0 errors and repaired 0 errors%' AND [err ] NOT LIKE '%LOG\ERRORLOG%' AND [err] NOT LIKE '%without errors%')
		-- and err not like '%The SQL Network Interface%'
		ORDER BY [err];

	--Collect the Error message second row.
	INSERT #errfound
	SELECT el.[date_time] AS 'Date'
			,el.[ProcessInfo]
			,REPLACE(REPLACE(REPLACE(el.[err], ',', ''), CHAR(10), '|'), CHAR(13), '') AS 'Message'
			,el.[countrow] 
	FROM #errlog el 
		JOIN #errfound ef ON (el.[countrow] = ef.[countrow] + 1)
	WHERE ef.[message] LIKE '%Error:%Severity:%State:%'
	  AND (el.[err] NOT LIKE '%error%' AND el.[err] NOT LIKE '%failed%') --make sure there are no duplicate rows.

	--Display the errors.
	IF (SELECT COUNT(*) FROM #errfound) > 0
	BEGIN
		SELECT [date_time]
			,[ProcessInfo]
			,@client AS [servername]
			,[message] 
		FROM #errfound
		ORDER BY [date_time] DESC;
	END
	ELSE
	BEGIN
	--this will need to be changed as the number of columns is not correct
		SELECT GETDATE() AS [date_time]
			,'' AS 'ProcessInfo'
			,@client AS [servername]
			,'There are no error log messages' AS [message];
	END
	
	--drop the table to tidy up
	DROP TABLE #errlog;
	DROP TABLE #errfound;

	IF (SELECT [value] FROM [dbo].[static_parameters] WHERE [name] = 'PROGRAM_NAME') = PROGRAM_NAME()
			UPDATE [dbo].[procedure] SET [last_execution_datetime] = GETDATE() WHERE [procedure_id] = @@PROCID;

	REVERT;
END
GO
