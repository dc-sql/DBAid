CREATE FUNCTION [get].[check_configuration]
(
	@procedure_name NVARCHAR(128) = NULL,
	@config_name NVARCHAR(128) = NULL,
	@ci_name NVARCHAR(128) = NULL
)
RETURNS TABLE
WITH ENCRYPTION
RETURN
(
	SELECT [config_name], [ci_name], [check_value], [check_change_alert]
	FROM [setting].[check_configuration] 
	WHERE ([procedure_name] = @procedure_name COLLATE Latin1_General_CI_AS OR ISNULL(@procedure_name,'') = '')
		AND ([config_name] = @config_name COLLATE Latin1_General_CI_AS OR ISNULL(@config_name,'') = '')
		AND ([ci_name] = @ci_name COLLATE Latin1_General_CI_AS OR ISNULL(@ci_name,'') = '')
)

