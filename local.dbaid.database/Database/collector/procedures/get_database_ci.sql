/*



*/

CREATE PROCEDURE [collector].[get_database_ci]
(
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @cmd NVARCHAR(MAX), @columns NVARCHAR(MAX), @casts NVARCHAR(MAX);
	DECLARE @colist AS TABLE(col NVARCHAR(128));

	INSERT INTO @colist
		SELECT [name] 
		FROM [master].sys.all_columns
		WHERE [object_id] = OBJECT_ID(N'sys.databases')
			AND [name] NOT LIKE N'name'
		ORDER BY [column_id];

	SELECT @columns = COALESCE(@columns + ', ', '') + QUOTENAME([col])
		,@casts = COALESCE(@casts + ', ', '') + QUOTENAME([col]) + N'=CAST(' + QUOTENAME([col]) + N' AS SQL_VARIANT)'
	FROM @colist

	SET @cmd = N'SELECT [instance_guid], [datetimeoffset], [name], [property], [value] 
		FROM (SELECT [i].[instance_guid]
			,[o].[datetimeoffset]
			,[name]
			,' + @casts 
		+ N' FROM sys.databases [d] 
			CROSS APPLY [system].[get_instance_guid]() [i] 
			CROSS APPLY [system].[get_datetimeoffset](NULL) [o]
			) [p] UNPIVOT ([value] FOR [property] IN (' 
		+ @columns 
		+ N')) AS [unpvt];';
	EXEC(@cmd);

	IF (@update_execution_timestamp = 1)
		MERGE INTO [collector].[last_execution] AS [Target]
		USING (SELECT OBJECT_NAME(@@PROCID), GETDATE()) AS [Source]([object_name],[last_execution])
		ON [Target].[object_name] = [Source].[object_name]
		WHEN MATCHED THEN
			UPDATE SET [Target].[last_execution] = [Source].[last_execution]
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT ([object_name],[last_execution]) VALUES ([Source].[object_name],[Source].[last_execution]);
END
