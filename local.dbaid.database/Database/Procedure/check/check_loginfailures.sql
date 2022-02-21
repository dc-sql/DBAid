/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [check].[loginfailures] (@show_detail bit = 0 /* Option to allow DBA to retrieve list of login failure detail */)
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

    DECLARE @Totals TABLE ([count] int, [name] sysname, [failed_login_threshold] int NULL, [monitoring_period_minutes] int NULL, [state] sysname DEFAULT N'OK');

    SELECT @msg = '';

    SELECT @DefaultMonitoringPeriod = [monitoring_period_minutes],
           @DefaultLoginThreshold = [failed_login_threshold],
           @DefaultState = [login_failure_alert]
    FROM [_dbaid].[dbo].[config_login_failures] 
    WHERE [name] = N'_dbaid_default';

    -- Extended Events use UTC, so do the conversion
    SET @StartTime = DATEADD(minute, -@DefaultMonitoringPeriod, GETDATE()); --modify this to suit your needs
    SET @EndTime = GETDATE();
    SET @UTCOffset = DATEDIFF(minute, GETDATE(), GETUTCDATE());
    SET @StartTime = DATEADD(minute, @UTCOffset, @StartTime);
    SET @EndTime = DATEADD(minute, @UTCOffset, @EndTime);

    -- Get raw XML data from ring buffer
    SELECT @target_data = CONVERT(xml, target_data)
    FROM sys.dm_xe_sessions AS s 
      INNER JOIN sys.dm_xe_session_targets AS t 
        ON t.event_session_address = s.address
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
      -- There can be two events logged in the Extended Event data for a login failure. We only need to capture one of them, otherwise counts will be inflated.
      SELECT src.xeXML
             ,src.xeXML.value('(/event/@timestamp)[1]', 'datetimeoffset(7)') AS "xeTimeStamp"
             ,SUBSTRING(src.xeXML.value('(/event/data/value)[8]', 'nvarchar(2000)'), 24, PATINDEX('%''.%', src.xeXML.value('(/event/data/value)[8]', 'nvarchar(2000)')) - 24) AS "name"
      FROM src
      WHERE src.xeXML.value('(/event/data/type/@name)[6]', 'nvarchar(2000)') = 'error_destination'
        AND src.xeXML.value('(/event/data/value)[6]', 'nvarchar(2000)') = '0x0000001c'
    )
    ,filteredevents AS
    (
      -- Combine data from event session & DBAid config table to allow for easier check of thresholds
      -- Where there is no exception in the config table for a login, use the default value (handled by CROSS APPY & COALESCE statements)
      -- Filter out excluded logins (failed_login_threshold = 0 or monitoring_period_minutes = 0)
      SELECT af.[xeTimeStamp]
            ,af.[name]
            ,COALESCE(clf.[failed_login_threshold], @DefaultLoginThreshold) AS "failed_login_threshold"
            ,COALESCE(clf.[monitoring_period_minutes], @DefaultMonitoringPeriod) AS "monitoring_period_minutes"
      FROM AllFailures af
        LEFT OUTER JOIN [_dbaid].[dbo].[config_login_failures] clf 
          ON af.[name] = clf.[name] 
        CROSS APPLY (SELECT [failed_login_threshold], [monitoring_period_minutes] 
                     FROM [_dbaid].[dbo].[config_login_failures] 
                     WHERE [name] = N'_dbaid_default') d
      WHERE COALESCE(clf.[failed_login_threshold], @DefaultLoginThreshold) <> 0
         OR COALESCE(clf.[monitoring_period_minutes], @DefaultMonitoringPeriod) <> 0
    )
    INSERT INTO @Totals ([count], [name], [failed_login_threshold], [monitoring_period_minutes])
      -- Total login failures
      SELECT COUNT(CONVERT(varchar(30), DATEADD(minute, 0 - @UTCOffset, xr.xeTimeStamp), 100)) AS "count"  -- convert timestamp to nearest minute
             ,COALESCE(xr.[name], N'_Total') AS "name"
             ,@DefaultLoginThreshold
             ,@DefaultMonitoringPeriod
      FROM filteredevents xr
      WHERE xr.xeTimeStamp >= DATEADD(minute, -@DefaultMonitoringPeriod, SYSUTCDATETIME())
      GROUP BY xr.[name] WITH ROLLUP
      HAVING COALESCE(xr.[name], N'_Total') = N'_Total'
      UNION
      -- Login failures per login that exists in config table (i.e., they have different threshold to the default)
      SELECT COUNT(CONVERT(varchar(30), DATEADD(minute, 0 - @UTCOffset, xr.xeTimeStamp), 100)) AS "count"  -- convert timestamp to nearest minute
             ,COALESCE(xr.[name], N'_Total') AS "name"
             ,clf.[failed_login_threshold]
             ,clf.[monitoring_period_minutes]
      FROM filteredevents xr
        INNER JOIN [_dbaid].[dbo].[config_login_failures] clf 
          ON xr.[name] = clf.[name]
      WHERE xr.xeTimeStamp >= DATEADD(minute, -clf.[monitoring_period_minutes], SYSUTCDATETIME())
      GROUP BY xr.[name], clf.[failed_login_threshold], clf.[monitoring_period_minutes]
      HAVING COALESCE(xr.[name], N'_Total') <> N'_Total'

    -- Set state as required. Only need to check [count] against threshold as time period was handled in INSERT statement above.
    UPDATE t
    SET t.[state] = clf.[login_failure_alert]
    FROM @Totals t
      INNER JOIN [_dbaid].[dbo].[config_login_failures] clf 
        ON clf.[name] = t.[name]
    WHERE t.[count] >= t.[failed_login_threshold];

    IF EXISTS (SELECT 1 FROM @Totals WHERE [name] = N'_Total')
      UPDATE @Totals
      SET [state] = @DefaultState
      WHERE [name] = N'_Total'
        AND [count] >= @DefaultLoginThreshold;

    IF (SELECT COUNT(*) FROM @Totals) = 0
      SELECT N'Total number of login failures in the last ' + CAST(@DefaultMonitoringPeriod AS nvarchar(20)) + N' minutes was 0' AS "message", N'NA' AS "state";
    ELSE IF EXISTS (SELECT 1 FROM @Totals WHERE [state] IN (N'WARNING', N'CRITICAL') AND [name] <> N'_Total')
           SELECT TOP (1) N'Total number of login failures for a monitored login was ' + CAST([count] AS nvarchar(20)) + N', exceeding threshold of ' + CAST([failed_login_threshold] AS nvarchar(20)) + N' per ' + CAST([monitoring_period_minutes] AS nvarchar(20)) + N' minute window.' AS "message", [state] FROM @Totals WHERE [name] <> N'_Total' AND [state] IN (N'WARNING', N'CRITICAL') ORDER BY [state] ASC, [count] DESC;
         ELSE IF EXISTS (SELECT 1 FROM @Totals WHERE [state] IN (N'WARNING', N'CRITICAL') AND [name] = N'_Total')
                SELECT N'Total number of login failures in the last ' + CAST(@DefaultMonitoringPeriod AS nvarchar(20)) + N' minutes was ' + CAST([count] AS nvarchar(20)) + N', exceeding threshold of ' + CAST([failed_login_threshold] AS nvarchar(20)) AS "message", [state] FROM @Totals WHERE [name] = N'_Total';
              ELSE 
                SELECT N'Total number of login failures in the last ' + CAST(@DefaultMonitoringPeriod AS nvarchar(20)) + N' minutes was ' + CAST([count] AS nvarchar(20)) + N', below threshold of ' + CAST([failed_login_threshold] AS nvarchar(20)) + N' per ' + CAST([monitoring_period_minutes] AS nvarchar(20)) + N' minute window.'AS "message", N'OK' AS "state" FROM @Totals WHERE [name] = N'_Total';

    IF @show_detail = 1
    BEGIN
      /* Using CTEs to get list of explicit login names listed first in order of alert criticality & failure count
           then the overall total. 
         When an alert is generated, an alert for an explicit login will override the total, so want to show the
           detail in that order as well, to make it clear which login generated the failure. Assuming, of course, 
           that the audit is done before the alert clears. If not, there's always the SQL ERRORLOG for auditing.
      */
      ;WITH [ExplicitLoginFailures] ([count], [name], [failed_login_threshold], [monitoring_period_minutes], [state]) AS
      (
        SELECT TOP (100) PERCENT [count], [name], [failed_login_threshold], [monitoring_period_minutes], [state]
        FROM @Totals
        WHERE [name] <> N'_Total'
        ORDER BY [state] ASC, [count] DESC
      ),
      [TotalLoginFailures] ([count], [name], [failed_login_threshold], [monitoring_period_minutes], [state]) AS
      (
        SELECT [count], [name], [failed_login_threshold], [monitoring_period_minutes], [state]
        FROM @Totals
        WHERE [name] = N'_Total'
      )
      SELECT * FROM [ExplicitLoginFailures]
      UNION
      SELECT * FROM [TotalLoginFailures];
    END

END
GO