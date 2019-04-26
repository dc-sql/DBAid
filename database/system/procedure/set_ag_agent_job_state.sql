/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [system].[set_ag_agent_job_state] @ag_name sysname, @wait_seconds int = 30
WITH ENCRYPTION
AS

BEGIN
/* 
This procedure determines if the replica is the primary or a secondary. 
If it is primary, it enables jobs in the "_dbaid_AG_primary_only" category. If not, it disables them. 
If it is secondary, it enables jobs in the "_dbaid_AG_secondary_only" category. If not, it disables them. 
*/
    
  SET NOCOUNT ON;

  /* allow time for roles to change, otherwise jobs won't get updated as intended */
  WAITFOR DELAY @wait_seconds;

  DECLARE @_job_id uniqueidentifier
          ,@_is_primary_replica tinyint
          ,@_is_secondary_replica tinyint
          ,@_dbaid_AG_primary_only sysname = N'_dbaid_AG_primary_only'      /* maybe have a lookup table for this */
          ,@_dbaid_AG_secondary_only sysname = N'_dbaid_AG_secondary_only'  /* maybe have a lookup table for this */
          ,@_primary_replica sysname
          ,@_current_replica sysname = UPPER(@@SERVERNAME) /* returns server\instance (no \instance if default) */
          ,@_params nvarchar(100)
          ,@_sql nvarchar(max);

  /* Check location of Availability Group */
  /* returns server\instance (no \instance if default) */
  SET @_sql = N'SELECT @_out_primary_replica = UPPER([ags].[primary_replica])
                FROM [sys].[dm_hadr_name_id_map] [nim]
                INNER JOIN [sys].[dm_hadr_availability_group_states] [ags]
                  ON [nim].[ag_id] = [ags].[group_id]
                WHERE [nim].[ag_name] = @ag_name;';
  SET @_params = N'@ag_name sysname, @_out_primary_replica sysname OUTPUT';
  
  EXEC sp_executesql @_sql, @_params, @ag_name, @_out_primary_replica = @_primary_replica OUT;

  /* set primary/secondary replica flags */
  IF @_primary_replica = @_current_replica
  BEGIN
    SET @_is_primary_replica = 1;
    SET @_is_secondary_replica = 0;
  END
  ELSE
  BEGIN
    SET @_is_primary_replica = 0;
    SET @_is_secondary_replica = 1;
  END

  /*  Loop through ALL SQL Agent Jobs intended to run on primary replica, and set the @enabled property to the value returned above. */
  /*  i.e. if primary, enable jobs intended to run on primary only; if secondary, disable jobs intended to run on primary only. */
  DECLARE job_id_cursor CURSOR FOR
    SELECT [j].[job_id] 
    FROM [msdb].[dbo].[sysjobs] [j]
      INNER JOIN [msdb].[dbo].[syscategories] [c] 
        ON [j].[category_id] = [c].[category_id]
    WHERE [c].[name] = @_dbaid_AG_primary_only;

  /*  Update jobs */
  OPEN job_id_cursor;
  FETCH NEXT from job_id_cursor into @_job_id;

  WHILE @@Fetch_Status = 0     
  BEGIN
    EXEC [msdb].[dbo].[sp_update_job] @job_id = @_job_id, @enabled = @_is_primary_replica; 
    FETCH NEXT FROM job_id_cursor INTO @_job_id;
  END 

  CLOSE job_id_cursor;
  DEALLOCATE job_id_cursor;
    
    
    
  /*  Loop through ALL SQL Agent Jobs intended to run on secondary replica, and set the @enabled property to the value returned above. */
  /*  i.e. if secondary, enable jobs intended to run on secondary only; if primary, disable jobs intended to run on secondary only. */
  DECLARE job_id_cursor CURSOR FOR
    SELECT [j].[job_id] 
    FROM [msdb].[dbo].[sysjobs] [j]
      INNER JOIN [msdb].[dbo].[syscategories] [c] 
        ON [j].[category_id] = [c].[category_id]
    WHERE [c].[name] = @_dbaid_AG_secondary_only;

  /*  Update jobs */
  OPEN job_id_cursor;
  FETCH NEXT from job_id_cursor into @_job_id;

  WHILE @@Fetch_Status = 0     
  BEGIN
    EXEC [msdb].[dbo].[sp_update_job] @job_id = @_job_id, @enabled = @_is_secondary_replica; 
    FETCH NEXT FROM job_id_cursor INTO @_job_id;
  END 

  CLOSE job_id_cursor;
  DEALLOCATE job_id_cursor;
END