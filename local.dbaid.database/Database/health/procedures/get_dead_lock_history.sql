/*



*/

CREATE PROCEDURE [health].[get_dead_lock_history]
WITH ENCRYPTION
AS
BEGIN
	DECLARE @xml XML;

	SELECT TOP(1) @xml = CAST(target_data AS XML)
	FROM sys.dm_xe_session_targets [t]
		JOIN sys.dm_xe_sessions [s] 
			ON [t].[event_session_address] = [s].[address]
	WHERE name = 'system_health'
		AND [t].[target_name] = 'ring_buffer'
 
	SELECT [xml_deadlock_report] = [n].[data].[query]('.')
	FROM @xml.nodes('//RingBufferTarget/event') AS [n]([data])
	WHERE [n].[data].[value]('@name','VARCHAR(4000)') = 'xml_deadlock_report'
END
