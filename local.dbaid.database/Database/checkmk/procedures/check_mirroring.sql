/*



*/

CREATE PROCEDURE [checkmk].[check_mirroring]
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([state] VARCHAR(8), [message] NVARCHAR(4000));

	INSERT INTO @check_output
	SELECT CASE WHEN ([M].[mirroring_state] NOT IN (2,4) OR [C].[mirroring_check_role] != [M].[mirroring_role_desc] COLLATE DATABASE_DEFAULT) 
			THEN [C].[mirroring_check_alert] ELSE 'OK' END AS [state]
		,'database=' + QUOTENAME([D].[name]) COLLATE DATABASE_DEFAULT
		+ '; state=' + UPPER([M].[mirroring_state_desc]) COLLATE DATABASE_DEFAULT
		+ '; expected_role=' + UPPER([C].[mirroring_check_role]) COLLATE DATABASE_DEFAULT
		+ '; current_role=' + UPPER([M].[mirroring_role_desc]) COLLATE DATABASE_DEFAULT AS [message]
	FROM [master].[sys].[databases] [D]
		INNER JOIN [master].[sys].[database_mirroring] [M]
			ON [D].[database_id] = [M].[database_id]
		INNER JOIN [checkmk].[config_database] [C]
			ON [D].[name] = [C].[name] COLLATE DATABASE_DEFAULT
	WHERE [C].[mirroring_check_enabled] = 1
		AND [M].[mirroring_guid] IS NOT NULL;

	IF (SELECT COUNT(*) FROM @check_output) < 1
		INSERT INTO @check_output VALUES('NA', 'Mirroring is currently not configured.');

	SELECT [state], [message] FROM @check_output;

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