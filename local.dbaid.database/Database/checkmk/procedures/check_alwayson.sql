/*



*/

CREATE PROCEDURE [checkmk].[check_alwayson]
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @check_output TABLE([state] VARCHAR(8), [message] NVARCHAR(4000));

	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN
		INSERT INTO @check_output
			EXEC [dbo].[sp_executesql] @stmt = N'SELECT CASE 
														WHEN [HA].[ag_state_is_enabled] = 1 AND
															([RS].[synchronization_health] NOT IN (2) 
															OR [RS].[connected_state] NOT IN (1)) 
														THEN [HA].[ag_state_alert]
														WHEN [HA].[ag_role_is_enabled] = 1 AND
															([HA].[ag_role] != [RS].[role_desc] COLLATE DATABASE_DEFAULT)
															THEN [HA].[ag_role_alert]	
														ELSE ''OK'' END AS [state]
													,''ag='' 
													+ [AG].[name] COLLATE DATABASE_DEFAULT 
													+ ''; sync='' 
													+ [RS].[synchronization_health_desc] COLLATE DATABASE_DEFAULT 
													+ ''; conn='' + [RS].[connected_state_desc] COLLATE DATABASE_DEFAULT
													+ ''; exp_role='' + [HA].[ag_role]
													+ ''; curr_role='' + [RS].[role_desc] COLLATE DATABASE_DEFAULT 
													+ ''; '' AS [message]
												FROM [master].[sys].[dm_hadr_availability_group_states] [GS]
													INNER JOIN [master].[sys].[availability_groups] [AG] 
														ON [AG].[group_id] = [GS].[group_id]
													INNER JOIN [checkmk].[config_alwayson] [HA] 
														ON [HA].[ag_id] = [AG].[group_id]
													INNER JOIN [sys].[dm_hadr_availability_replica_states] [RS] 
														ON [RS].[group_id] = [AG].[group_id]
															AND [RS].[is_local] = 1';
		
		IF (SELECT COUNT(*) FROM @check_output) = 0
		BEGIN
			INSERT INTO @check_output VALUES('NA', 'Always-On is currently not configured.')
				SELECT [state], [message] FROM @check_output;
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT 1 FROM @check_output WHERE [state] IN ('CRITICAL','WARNING'))
			BEGIN
				SELECT [state], [message] FROM @check_output WHERE [state] NOT IN ('OK');

				IF (@writelog = 1)
				BEGIN
					DECLARE @ErrorMsg NVARCHAR(2048);
					DECLARE ErrorCurse CURSOR FAST_FORWARD FOR 
						SELECT [state] + N' - ' + OBJECT_NAME(@@PROCID) + N' - ' + [message] 
						FROM @check_output 
						WHERE [state] NOT IN ('NA','OK');

					OPEN ErrorCurse;
					FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;

					WHILE (@@FETCH_STATUS=0)
					BEGIN
						EXEC xp_logevent 54321, @ErrorMsg, 'WARNING';  
						FETCH NEXT FROM ErrorCurse INTO @ErrorMsg;
					END

					CLOSE ErrorCurse;
					DEALLOCATE ErrorCurse;
				END
			END
			ELSE
				SELECT 'OK' AS [state], 'Always-On ('+(SELECT CAST(COUNT(*) AS NVARCHAR(3)) FROM @check_output) +') availability groups healthy.' AS [message];
		END
	END
	ELSE
	BEGIN
		SELECT 'NA' AS [state], 'Always-On is not available.' AS [message];
	END
END;

