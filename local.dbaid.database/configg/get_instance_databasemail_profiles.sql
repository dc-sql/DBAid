/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_instance_databasemail_profiles]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @mailconfiguration TABLE ([paramname] NVARCHAR(256)
										,[paramvalue] NVARCHAR(256)
										,[description] NVARCHAR(256));

	DECLARE @mailprofileaccount TABLE ([profile_id] INT
										,[profile_name] NVARCHAR(128)
										,[account_id] INT
										,[account_name] NVARCHAR(128)
										,[sequence_number] INT);

	DECLARE @mailaccount TABLE ([account_id] INT
								,[name] NVARCHAR(128)
								,[description] NVARCHAR(256)
								,[email_address] NVARCHAR(128)
								,[display_name] NVARCHAR(128)
								,[replyto_address] NVARCHAR(128)
								,[servertype] NVARCHAR(128)
								,[servername] NVARCHAR(128)
								,[port] INT
								,[username] NVARCHAR(128)
								,[use_default_credentials] BIT
								,[enable_ssl] BIT);

	DECLARE @mailprincipalprofile TABLE ([principal_id] INT
										,[principal_name] NVARCHAR(128)
										,[profile_id] INT
										,[profile_name] NVARCHAR(128)
										,[is_default] BIT);

	INSERT INTO @mailconfiguration EXEC [msdb].[dbo].[sysmail_help_configure_sp];
	INSERT INTO @mailaccount EXEC [msdb].[dbo].[sysmail_help_account_sp];
	INSERT INTO @mailprofileaccount EXEC [msdb].[dbo].[sysmail_help_profileaccount_sp];
	INSERT INTO @mailprincipalprofile EXEC [msdb].[dbo].[sysmail_help_principalprofile_sp];

	SELECT [PA].[profile_name]
		,CAST([PP].[profile_principals] AS XML) AS [profile_principals]
		,CAST([MA].[mail_accounts] AS XML) AS [mail_accounts]
	FROM @mailprofileaccount [PA]
		CROSS APPLY (SELECT (SELECT [principal_name], [is_default] FROM @mailprincipalprofile WHERE [profile_id] = [PA].[profile_id] FOR XML PATH('principal')) AS [profile_principals]) [PP]
		CROSS APPLY (SELECT (SELECT [name]
									,[description]
									,[email_address]
									,[display_name]
									,[replyto_address]
									,[servername]
									,[port]
									,[username]
									,[use_default_credentials]
									,[enable_ssl] 
								FROM @mailaccount [A]
									INNER JOIN @mailprofileaccount [B]
										ON [A].[account_id] = [B].[account_id]
								WHERE [B].[profile_id] = [PA].[profile_id] 
								ORDER BY [B].[sequence_number] FOR XML PATH('account')) AS [mail_accounts]) [MA]
	GROUP BY [PA].[profile_name]
		,[PP].[profile_principals]
		,[MA].[mail_accounts];
END