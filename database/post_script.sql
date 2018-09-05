/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/
USE [$(DatabaseName)];
GO

/* Insert static variables */
MERGE INTO [system].[configuration] AS [Target] 
USING (SELECT N'INSTANCE_GUID', CAST(NEWID() AS SQL_VARIANT)
	UNION SELECT N'CAPACITY_CACHE_RETENTION_MONTH',3
) AS [Source] ([key],[value])  
ON [Target].[key] = [Source].[key] 
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([key],[value]) 
	VALUES ([Source].[key],[Source].[value]);
GO

/* Insert wmi queries */
MERGE INTO [configg].[wmi_query] AS [Target] 
USING (VALUES('SELECT * FROM SqlService WHERE DisplayName LIKE ''%@@SERVICENAME%'' OR ServiceName = ''SQLBrowser''')
,('SELECT * FROM ServerNetworkProtocol WHERE InstanceName LIKE ''%@@SERVICENAME%''')
,('SELECT * FROM ServerNetworkProtocolProperty WHERE IPAddressName = ''IPAll'' AND InstanceName LIKE ''%@@SERVICENAME%''')
,('SELECT * FROM SqlServiceAdvancedProperty WHERE ServiceName LIKE ''%@@SERVICENAME%''')
,('SELECT * FROM ServerSettingsGeneralFlag WHERE InstanceName LIKE ''%@@SERVICENAME%''')
,('SELECT * FROM Win32_OperatingSystem')
,('SELECT * FROM Win32_TimeZone')
,('SELECT * FROM win32_processor')
,('SELECT * FROM Win32_computerSystem')
,('SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = ''TRUE''')
,('SELECT * FROM Win32_Volume WHERE SystemVolume <> ''TRUE'' AND DriveType <> 4 AND DriveType <> 5')
,('SELECT * FROM Win32_GroupUser WHERE GroupComponent="Win32_Group.Domain=''@@HOSTNAME'',Name=''administrators''"')
) AS [Source] ([query])  
ON [Target].[query] = [Source].[query] 
WHEN NOT MATCHED BY TARGET THEN  
	INSERT ([query]) 
	VALUES ([Source].[query]);
GO

/* execute inventory */
EXEC [checkmk].[inventory_database];
GO
EXEC [checkmk].[inventory_agentjob];
GO

