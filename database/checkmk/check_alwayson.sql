/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[usp_check_alwayson]
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check TABLE([message] NVARCHAR(4000)
						,[state] NVARCHAR(8));

	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN
		INSERT INTO @check
			EXEC [dbo].[sp_executesql] @stmt = N'SELECT 
													N''ag='' 
													+ [AG].[name] COLLATE Database_Default 
													+ N''; sync='' 
													+ [RS].[synchronization_health_desc] COLLATE Database_Default 
													+ N''; conn='' + [RS].[connected_state_desc] COLLATE Database_Default
													+ N''; exp_role='' + [HA].[ag_role]
													+ N''; curr_role='' + [RS].[role_desc] COLLATE Database_Default 
													+ N''; '' AS [message]
													,CASE 
														WHEN [HA].[ag_state_is_enabled] = 1 AND
															([RS].[synchronization_health] NOT IN (2) 
															OR [RS].[connected_state] NOT IN (1)) 
														THEN [HA].[ag_state_alert]
														WHEN [HA].[ag_role_is_enabled] = 1 AND
															([HA].[ag_role] != [RS].[role_desc] COLLATE Database_Default)
															THEN [HA].[ag_role_alert]	
														ELSE N''OK'' END AS [state]
												FROM [master].[sys].[dm_hadr_availability_group_states] [GS]
													INNER JOIN [master].[sys].[availability_groups] [AG] 
														ON [AG].[group_id] = [GS].[group_id]
													INNER JOIN [setting].[check_alwayson] [HA] 
														ON [HA].[ag_id] = [AG].[group_id]
													INNER JOIN [sys].[dm_hadr_availability_replica_states] [RS] 
														ON [RS].[group_id] = [AG].[group_id]
															AND [RS].[is_local] = 1';
		
		IF (SELECT COUNT(*) FROM @check) = 0
		BEGIN
			INSERT INTO @check VALUES(N'Always-On is currently not configured.',N'NA')
				SELECT [message], [state] FROM @check;
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT 1 FROM @check WHERE [state] IN ('CRITICAL','WARNING'))
				SELECT [message], [state] FROM @check WHERE [state] NOT IN ('OK');
			ELSE
				SELECT N'Always-On ('+(SELECT CAST(COUNT(*) AS NVARCHAR(3)) FROM @check) +') availability groups healthy.' AS [message],N'OK' AS [state];
		END
	END
	ELSE
	BEGIN
		SELECT N'Always-On is not available.' AS [message], N'NA' AS [state]
	END
END;
