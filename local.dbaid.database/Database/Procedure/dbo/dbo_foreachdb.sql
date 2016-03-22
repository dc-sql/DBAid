/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [dbo].[foreachdb]
(
	@cmd NVARCHAR(MAX)
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @databases TABLE ([name] NVARCHAR(130) NOT NULL);
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @db NVARCHAR(130);
	DECLARE @error NVARCHAR(4000);
	DECLARE @state NVARCHAR(60);

	INSERT INTO @databases
		SELECT [name] FROM sys.databases
		WHERE [state] = 0 AND HAS_DBACCESS([name]) = 1;

	WHILE (SELECT COUNT([name]) FROM @databases) > 0
	BEGIN
		SELECT TOP 1 @db=[name] FROM @databases;
		DELETE FROM @databases WHERE [name] = @db;

		SELECT @state=[state_desc] FROM sys.databases WHERE [name] = @db;

		IF (@state = N'ONLINE')
		BEGIN
			BEGIN TRY
				SET @sql = REPLACE(@cmd, '?', @db);
				EXEC(@sql);
			END TRY
			BEGIN CATCH
				PRINT ERROR_MESSAGE();
			END CATCH
		END
		ELSE
		BEGIN 
			SET @error = N'Database [' + @db + N'] changed state to "' + @state + N'" during operation. Skipping database.'
			PRINT @error
		END
	END
END