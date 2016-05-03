CREATE PROCEDURE [dbo].[instance_tag]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @domain NVARCHAR(128);

	SELECT @domain = CAST([value] AS NVARCHAR(128)) FROM [dbo].[service] WHERE [property] = N'Domain';

	IF (@domain IS NULL)
	BEGIN
		EXECUTE AS LOGIN = N'$(DatabaseName)_sa';

		EXEC [master].[dbo].[xp_regread] @rootkey='HKEY_LOCAL_MACHINE', @key='SYSTEM\ControlSet001\Services\Tcpip\Parameters\',@value_name='Domain',@value=@domain OUTPUT;
		
		REVERT;
		REVERT;
	END

	SELECT REPLACE(REPLACE(@@SERVERNAME, '\', '@'),'_','~') + N'_' + REPLACE(@domain, '.', '_') AS [instance_tag]
END