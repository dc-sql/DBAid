/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [system].[execute_foreach_db]
(
	@cmd NVARCHAR(MAX)
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @databases TABLE ([name] NVARCHAR(130) NOT NULL);
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @db NVARCHAR(128);
	DECLARE @error NVARCHAR(4000);
	DECLARE @state NVARCHAR(60);

	INSERT INTO @databases
		SELECT [name] 
		FROM sys.databases WITH (NOLOCK)
		WHERE [state] = 0 AND HAS_DBACCESS([name]) = 1;

	DECLARE db_curse CURSOR FAST_FORWARD
	FOR SELECT [name] FROM @databases;

	OPEN db_curse;
	FETCH NEXT FROM db_curse INTO @db; 

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @state=[state_desc] 
		FROM sys.databases WITH (NOLOCK)
		WHERE [name] = @db;

		IF (@state = N'ONLINE')
		BEGIN
			BEGIN TRY
				SET @sql = REPLACE(@cmd, '?', @db);
				FETCH NEXT FROM db_curse INTO @db;
				EXEC sp_executesql @sql;
			END TRY
			BEGIN CATCH
				PRINT ERROR_MESSAGE();
				CONTINUE;
			END CATCH
		END
	END

	CLOSE db_curse;
	DEALLOCATE db_curse;
END