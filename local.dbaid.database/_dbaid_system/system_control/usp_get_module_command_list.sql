CREATE FUNCTION [dbo].[usp_get_module_command_list]
(
	@module_id TINYINT
)
RETURNS TABLE
RETURN
(
	SELECT [command]
		,[is_procedure]
	FROM [system].[tbl_module_command]
	WHERE [module_id] = @module_id
		AND [is_enabled] = 1
)
