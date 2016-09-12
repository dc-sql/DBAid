﻿CREATE FUNCTION [get].[instance_tag]()
RETURNS @returntable TABLE
(
	[instance_tag] NVARCHAR(256)
)
WITH ENCRYPTION, EXECUTE AS 'dbo'
BEGIN
	DECLARE @domain NVARCHAR(128);

	SELECT @domain = CAST([value] AS NVARCHAR(128)) FROM [dbo].[wmi_service_property] WHERE [property] = N'Domain';

	IF (@domain IS NULL)
		EXEC [master].[dbo].[xp_regread] @rootkey='HKEY_LOCAL_MACHINE', @key='SYSTEM\ControlSet001\Services\Tcpip\Parameters\',@value_name='Domain',@value=@domain OUTPUT;

	INSERT @returntable
	SELECT QUOTENAME(REPLACE(@@SERVERNAME, '\', '@')) + N'_' + REPLACE(@domain, '.', '_') AS [instance_tag]

	RETURN
END
