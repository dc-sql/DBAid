CREATE FUNCTION [system].[get_instance_tag]()
RETURNS @returntable TABLE
(
	[instance_tag] NVARCHAR(256)
)
WITH ENCRYPTION
BEGIN
	DECLARE @domain NVARCHAR(128);

	SELECT TOP(1) @domain = CAST([value] AS NVARCHAR(128)) 
	FROM [wmiload].[tbl_wmi_object] 
	WHERE [property] = N'Domain';

	IF (@domain IS NULL)
		EXEC [master].[dbo].[xp_regread] @rootkey='HKEY_LOCAL_MACHINE'
			,@key='SYSTEM\ControlSet001\Services\Tcpip\Parameters\'
			,@value_name='Domain'
			,@value=@domain OUTPUT;

	INSERT @returntable
		SELECT QUOTENAME(REPLACE(@@SERVERNAME, '\', '@')) + N'_' + REPLACE(@domain, '.', '_') AS [instance_tag]

	RETURN
END
