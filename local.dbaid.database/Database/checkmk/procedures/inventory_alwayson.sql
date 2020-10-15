/*



*/

CREATE PROCEDURE [checkmk].[inventory_alwayson]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN

		;WITH CTEAlwaysOn AS
		(
			SELECT [AG].[ag_name] 
				,[RS].[role_desc]
			FROM [sys].[dm_hadr_name_id_map] [AG]
				INNER JOIN [sys].[dm_hadr_availability_replica_cluster_states] [RCS] 
					ON [RCS].[group_id] = [AG].[ag_id] 
						AND [RCS].[replica_server_name] = @@SERVERNAME
				INNER JOIN [sys].[dm_hadr_availability_replica_states] [RS] 
					ON [RS].[group_id] = [AG].[ag_id] 
						AND [RS].[replica_id] = [RCS].[replica_id]
		)

		MERGE INTO [checkmk].[config_alwayson] [target]
		USING CTEAlwaysOn [source]
		ON [target].[ag_name] = [source].[ag_name] COLLATE DATABASE_DEFAULT
		WHEN NOT MATCHED BY TARGET THEN
			INSERT ([ag_name], [ag_role]) VALUES ([source].[ag_name], [source].[role_desc])
		WHEN MATCHED THEN
			UPDATE SET [target].[inventory_date] = GETDATE()
		WHEN NOT MATCHED BY SOURCE THEN
			DELETE;
	END
END

