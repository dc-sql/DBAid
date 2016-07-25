CREATE FUNCTION [get].[check_configuration]
(
	@object_name NVARCHAR(128),
	@item_name NVARCHAR(128),
	@column_name NVARCHAR(128)
)
RETURNS TABLE
WITH ENCRYPTION
RETURN
(
	SELECT [column_value], [change_alert]
	FROM [setting].[check_configuration] 
	WHERE [object_name] = @object_name COLLATE Latin1_General_CI_AS
		AND @item_name = @item_name COLLATE Latin1_General_CI_AS
		AND @column_name = @column_name COLLATE Latin1_General_CI_AS
)

