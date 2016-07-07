/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[serverobject]
WITH ENCRYPTION
AS
BEGIN 
	SET NOCOUNT ON;

	DECLARE @ServerObject TABLE([type] NVARCHAR(128)
		,[name] NVARCHAR(128)
		,[configuration] XML)

	/* Begin insert of Linked Server data */
	INSERT INTO @ServerObject
		SELECT N'LinkedServer' AS [type]
		,[A].[name]
		,CAST((SELECT [S].[product]
			,[S].[provider]
			,[S].[data_source]
			,[S].[provider_string]
			,[S].[location]
			,[S].[catalog]
			,CAST((SELECT [SP].[name] AS [local_login]
					,[LL].[uses_self_credential] AS [Impersonate]
					,[LL].[remote_name] AS [remote_login]
				FROM sys.linked_logins [LL] 
					LEFT JOIN sys.server_principals [SP] 
						ON [LL].[local_principal_id] = [SP].[principal_id]
				WHERE [LL].[server_id] = [S].[server_id]
					AND [LL].[local_principal_id] !=0
				FOR XML PATH('row'), ROOT('table')) AS XML) AS [login_mapping]
			,CASE 
				WHEN [L].[local_principal_id] = 0 AND [L].[uses_self_credential] = 0 AND ([L].[remote_name] IS NULL OR LTRIM(RTRIM([L].[remote_name])) = '')
					THEN 'Be made without using a security context'
				WHEN [L].[local_principal_id] = 0 AND [L].[uses_self_credential] = 1 AND ([L].[remote_name] IS NULL OR LTRIM(RTRIM([L].[remote_name])) = '')
					THEN 'Be made using the logins current security context'
				WHEN [L].[local_principal_id] = 0 AND [L].[uses_self_credential] = 0 AND ([L].[remote_name] IS NOT NULL OR LTRIM(RTRIM([L].[remote_name])) != '')
					THEN 'Be made using remote security context'
				ELSE 'Not be made' END AS [undefined_login_mapping]
			,[L].[remote_name] AS [remote_security_context]
			FROM sys.servers [S]
			LEFT JOIN sys.linked_logins [L] 
				ON [S].[server_id] = [L].[server_id]
					AND [L].[local_principal_id] = 0
			WHERE [S].[name] = [A].[name]
			FOR XML PATH(''),ROOT('table')) AS XML) AS [configuration]
		FROM sys.servers [A]
		WHERE [A].[is_linked] = 1
	/* End insert of Linked Server data */
	/* Begin insert of Server Trigger data */
	INSERT INTO @ServerObject
		SELECT N'ServerTrigger' AS [type]
		,[name]
		,CAST((SELECT [T].[create_date]
				,[T].[modify_date]
				,[T].[is_disabled]
				,ISNULL([M].[definition],'Encrypted') AS [definition]
			FROM sys.server_triggers [T]
				INNER JOIN sys.server_sql_modules [M]
					ON [T].[object_id] = [M].[object_id]
			WHERE [A].[name] = [T].[name]
			FOR XML PATH('row'), ROOT('table')) AS XML) AS [configuration]
		FROM sys.server_triggers [A]
	/* End insert of Server Trigger data */

	SELECT [type]
		,[name]
		,[configuration] 
	FROM @ServerObject
END