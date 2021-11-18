/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [checkmk].[check_loginfailures]
(
	@writelog BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @ExtendedEventsSessionName sysname = N'_dbaid_login_failures',
          @StartTime datetimeoffset,
          @EndTime datetimeoffset,
          @UTCOffset int,
          @DefaultMonitoringPeriod int,
          @DefaultLoginThreshold int,
          @DefaultState sysname,
          @target_data xml,
          @FailureCountTotal int,
          @msg varchar(max);

  DECLARE @Totals TABLE ([count] int, [name] sysname, [failed_login_threshold] int NULL, [state] sysname DEFAULT N'OK');

  SELECT @msg = '';

  SELECT @DefaultMonitoringPeriod = [monitoring_period_minutes],
         @DefaultLoginThreshold = [failed_login_threshold],
         @DefaultState = [login_failure_alert]
  FROM [_dbaid].[checkmk].[config_login_failures] 
  WHERE [name] = N'_dbaid_default';

  -- Extended Events use UTC, so do the conversion
  SET @EndTime = GETDATE();
  SET @StartTime = DATEADD(minute, -@DefaultMonitoringPeriod, @EndTime); --modify this to suit your needs
  SET @UTCOffset = DATEDIFF(minute, GETDATE(), GETUTCDATE());
  SET @StartTime = DATEADD(minute, @UTCOffset, @StartTime);
  SET @EndTime = DATEADD(minute, @UTCOffset, @EndTime);

  -- Get raw XML data from ring buffer
  SELECT @target_data = CONVERT(xml, target_data)
  FROM sys.dm_xe_sessions AS s 
    INNER JOIN sys.dm_xe_session_targets AS t ON t.event_session_address = s.address
  WHERE s.name = @ExtendedEventsSessionName
    AND t.target_name = N'ring_buffer';

  ;WITH src AS 
  (
      -- Start querying from [event] node(s) in XML data
      SELECT xeXML = xm.s.query('.')
      FROM @target_data.nodes('/RingBufferTarget/event') AS xm(s)
  )
  ,AllFailures AS
  (
    -- Get login failure message & timestamp data. Node 8 in event data is "Login failed for user..." message.
    SELECT src.xeXML
           ,src.xeXML.value('(/event/@timestamp)[1]', 'datetimeoffset(7)') AS "xeTimeStamp"
           ,SUBSTRING(src.xeXML.value('(/event/data/value)[8]', 'nvarchar(2000)'), 24, PATINDEX('%''.%', src.xeXML.value('(/event/data/value)[8]', 'nvarchar(2000)')) - 24) AS "name"
    FROM src
  )
  ,filteredevents AS
  (
    -- Combine data from event session & DBAid config table to allow for easier check of thresholds
    -- Where there is no exception in the config table for a login, use the default value (handled by CROSS APPY & COALESCE statements)
    -- Filter out excluded logins (failed_login_threshold = 0 or monitoring_period_minutes = 0)
    SELECT af.[xeTimeStamp], af.[name], COALESCE(clf.[failed_login_threshold], @DefaultLoginThreshold) AS "failed_login_threshold", COALESCE(clf.[monitoring_period_minutes], @DefaultMonitoringPeriod) AS "monitoring_period_minutes"
    FROM AllFailures af
      LEFT OUTER JOIN [_dbaid].[checkmk].[config_login_failures] clf ON af.[name] = clf.[name] 
  --    CROSS APPLY (SELECT [failed_login_threshold], [monitoring_period_minutes] FROM [_dbaid].[checkmk].[config_login_failures] WHERE [name] = N'_dbaid_default') d
    WHERE COALESCE(clf.[failed_login_threshold], @DefaultLoginThreshold) <> 0
       OR COALESCE(clf.[monitoring_period_minutes], @DefaultMonitoringPeriod) <> 0
  )
  INSERT INTO @Totals ([count], [name], [failed_login_threshold]/*, [monitoring_period_minutes]*/)
    -- Total login failures
    SELECT COUNT(CONVERT(varchar(30), DATEADD(minute, 0 - @UTCOffset, xr.xeTimeStamp), 100)) AS "count"  -- convert timestamp to nearest minute
           ,COALESCE(xr.[name], N'_Total') AS "name"
           ,@DefaultLoginThreshold
    FROM filteredevents xr
    WHERE xr.xeTimeStamp >= DATEADD(minute, -@DefaultMonitoringPeriod, SYSUTCDATETIME())
    GROUP BY xr.[name] WITH ROLLUP
    HAVING COALESCE(xr.[name], N'_Total') = N'_Total'
    UNION
    -- Login failures per login that exists in config table (i.e., they have different threshold to the default)
    SELECT COUNT(CONVERT(varchar(30), DATEADD(minute, 0 - @UTCOffset, xr.xeTimeStamp), 100)) AS "count"  -- convert timestamp to nearest minute
           ,COALESCE(xr.[name], N'_Total') AS "name"
           ,clf.[failed_login_threshold]
           --,clf.[monitoring_period_minutes]
    FROM filteredevents xr
      INNER JOIN [_dbaid].[checkmk].[config_login_failures] clf ON xr.[name] = clf.[name]
    WHERE xr.xeTimeStamp >= DATEADD(minute, -clf.[monitoring_period_minutes], SYSUTCDATETIME())
    GROUP BY xr.[name], clf.[failed_login_threshold], clf.[monitoring_period_minutes]
    HAVING COALESCE(xr.[name], N'_Total') <> N'_Total'

  -- Set state as required. Only need to check [count] against threshold as time period was handled in INSERT statement above.
  UPDATE @Totals
  SET [state] = @DefaultState
  WHERE [count] >= [failed_login_threshold];
 

  IF EXISTS (SELECT 1 FROM @Totals WHERE [state] = 'WARNING' AND [name] <> N'_Total')
    SELECT TOP (1) [state], N'Total number of login failures in the last ' + CAST(@DefaultMonitoringPeriod AS nvarchar(20)) + N' minutes for at least one specific login was ' + CAST([count] AS nvarchar(20)) + ', exceeding threshold of ' + CAST([failed_login_threshold] AS nvarchar(20)) AS [message] FROM @Totals WHERE [name] <> N'_Total' AND [state] = N'WARNING' ORDER BY ([count] - [failed_login_threshold]) DESC;
  ELSE IF EXISTS (SELECT 1 FROM @Totals WHERE [state] = 'WARNING' AND [name] = N'_Total')
         SELECT [state], N'Total number of login failures in the last ' + CAST(@DefaultMonitoringPeriod AS nvarchar(20)) + N' minutes was ' + CAST([count] AS nvarchar(20)) + ', exceeding threshold of ' + CAST([failed_login_threshold] AS nvarchar(20)) AS [message] FROM @Totals WHERE [name] = N'_Total';
       ELSE
         SELECT [state], N'Total number of login failures in the last ' + CAST(@DefaultMonitoringPeriod AS nvarchar(20)) + N' minutes was ' + CAST([count] AS nvarchar(20)) AS [message] FROM @Totals WHERE [name] = N'_Total';
END

