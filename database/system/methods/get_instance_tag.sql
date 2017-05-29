CREATE FUNCTION [system].[get_instance_tag]()
RETURNS @returntable TABLE
(
	[instance_tag] VARCHAR(256)
)
WITH ENCRYPTION
BEGIN
	DECLARE @domain VARCHAR(128);

	SELECT TOP(1) @domain = CAST([value] AS VARCHAR(128)) 
	FROM [configg].[service_properties]
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
