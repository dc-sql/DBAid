/*



*/

CREATE PROCEDURE [system].[get_instance_tag]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @sanitise BIT, @domain VARCHAR(128);

	SELECT @sanitise=CAST([value] AS BIT) FROM [system].[configuration] WHERE [key] = N'SANITISE_COLLECTOR_DATA';

	EXEC [master].[dbo].[xp_regread] @rootkey='HKEY_LOCAL_MACHINE'
		,@key='SYSTEM\ControlSet001\Services\Tcpip\Parameters\'
		,@value_name='Domain'
		,@value=@domain OUTPUT;

	IF (@sanitise = 1)
	BEGIN
		SELECT [instance_tag]=CAST([value] AS VARCHAR(36)) FROM [system].[configuration] WHERE [key] = N'INSTANCE_GUID'
	END
	ELSE
	BEGIN
		SELECT [instance_tag]=CAST(SERVERPROPERTY('MachineName') AS VARCHAR(128)) + '_' +  @@SERVICENAME + '_' + REPLACE(@domain, '.', '_');
	END
END
