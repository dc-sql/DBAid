CREATE PROCEDURE [configg].[get_link_server]
WITH ENCRYPTION
AS
BEGIN 
	SET NOCOUNT ON;

	SELECT 'INSTANCE' AS [heading], 'Link Servers' AS [subheading], '' AS [comment]

	SELECT [A].[name]
		,[A].[product]
		,[A].[provider]
		,[A].[data_source]
		,[A].[provider_string]
		,[A].[location]
		,[A].[catalog]
		,(SELECT CAST(
			(SELECT [SP].[name] AS [@local_login]
				,[LL].[uses_self_credential] AS [@impersonate]
				,[LL].[remote_name] AS [@remote_login]
				,CASE 
					WHEN [LL].[local_principal_id] = 0 AND [LL].[uses_self_credential] = 0 AND ([LL].[remote_name] IS NULL OR LTRIM(RTRIM([LL].[remote_name])) = '')
						THEN 'Be made without using a security context'
					WHEN [LL].[local_principal_id] = 0 AND [LL].[uses_self_credential] = 1 AND ([LL].[remote_name] IS NULL OR LTRIM(RTRIM([LL].[remote_name])) = '')
						THEN 'Be made using the logins current security context'
					WHEN [LL].[local_principal_id] = 0 AND [LL].[uses_self_credential] = 0 AND ([LL].[remote_name] IS NOT NULL OR LTRIM(RTRIM([LL].[remote_name])) != '')
						THEN 'Be made using remote security context'
					ELSE 'Not be made' END AS [@undefined_login_mapping]
				,[LL].[remote_name] AS [@remote_security_context]
			FROM sys.linked_logins [LL] 
				LEFT JOIN sys.server_principals [SP] 
					ON [LL].[local_principal_id] = [SP].[principal_id]
				WHERE [A].[server_id] = [LL].[server_id]
				FOR XML PATH('row'), ROOT('table'))
			AS XML)
		) AS [login_mapping]
	FROM sys.servers [A]
	WHERE [A].[is_linked] = 1;
END