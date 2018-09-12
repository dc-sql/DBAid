USE [_dbaid];
GO

DECLARE @cmd NVARCHAR(130);
DECLARE @procedures TABLE ([cmd] NVARCHAR(130));

INSERT INTO @procedures
	SELECT N'EXEC ' + QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) AS [procedure] FROM sys.objects WHERE[type] = 'P';

DECLARE curse CURSOR FAST_FORWARD
FOR SELECT [cmd] FROM @procedures;

OPEN curse;
FETCH NEXT FROM curse INTO @cmd;

WHILE (@@FETCH_STATUS = 0)
BEGIN
	BEGIN TRY
		EXEC(@cmd);
	END TRY
	BEGIN CATCH
		PRINT @cmd
		PRINT @@ERROR
	END CATCH
	FETCH NEXT FROM curse INTO @cmd;
END

CLOSE curse;
DEALLOCATE curse;