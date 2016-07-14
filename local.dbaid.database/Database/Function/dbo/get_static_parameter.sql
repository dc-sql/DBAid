CREATE FUNCTION [dbo].[get_static_parameter]
(
	@name VARCHAR(128)
)
RETURNS TABLE
WITH ENCRYPTION
RETURN
(
	SELECT [value] 
	FROM [setting].[static_parameters] 
	WHERE [name] = @name COLLATE Latin1_General_CI_AS
)

