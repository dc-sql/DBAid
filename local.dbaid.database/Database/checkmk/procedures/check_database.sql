/*



*/

CREATE PROCEDURE [checkmk].[check_database]
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([state] VARCHAR(8), [message] NVARCHAR(4000));
	DECLARE @onlinecount INT, @restorecount INT, @recovercount INT;

	INSERT INTO @check_output
		SELECT CASE WHEN [D].[state] IS NULL THEN [C].[database_check_alert] 
			WHEN [D].[state] NOT IN (0,1,2) THEN [C].[database_check_alert] 
			ELSE 'OK' END AS [state]
			,QUOTENAME([C].[name]) COLLATE DATABASE_DEFAULT 
			+ '=' + UPPER(ISNULL([D].[state_desc],'REMOVED')) COLLATE DATABASE_DEFAULT AS [message]
		FROM [sys].[databases] [D]
			RIGHT JOIN [checkmk].[config_database] [C] 
				ON [D].[name] = [C].[name] COLLATE DATABASE_DEFAULT
		WHERE [C].[database_check_enabled] = 1
		ORDER BY [D].[name];

	IF (SELECT COUNT(*) FROM @check_output WHERE [state] != 'OK') = 0
	BEGIN
		SELECT @onlinecount = COUNT([state]) FROM sys.databases WHERE [state] = 0;
		SELECT @restorecount = COUNT([state]) FROM sys.databases WHERE [state] = 1;
		SELECT @recovercount = COUNT([state]) FROM sys.databases WHERE [state] = 2;

		INSERT INTO @check_output 
		VALUES('NA', CAST(@onlinecount AS NVARCHAR(10)) + ' online; ' 
			+ CAST(@restorecount AS NVARCHAR(10)) + ' restoring; ' 
			+ CAST(@recovercount AS NVARCHAR(10)) + ' recovering');
	END

	SELECT [state], [message] FROM @check_output WHERE [state] != 'OK';

	IF (@writelog = 1)
	BEGIN
		DECLARE @ErrorMsg NVARCHAR(2048);
		DECLARE ErrorCurse CURSOR FAST_FORWARD FOR 
			SELECT [state] + N' - ' + OBJECT_NAME(@@PROCID) + N' - ' + [message] 
			FROM @check_output 
			WHERE [state] NOT IN ('NA','OK');

		OPEN ErrorCurse;
		FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;

		WHILE (@@FETCH_STATUS=0)
		BEGIN
			EXEC xp_logevent 54321, @ErrorMsg, 'WARNING';  
			FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;
		END

		CLOSE ErrorCurse;
		DEALLOCATE ErrorCurse;
	END
END
