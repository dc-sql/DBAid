/*



*/

CREATE PROCEDURE [health].[get_block_process_history]
WITH ENCRYPTION
AS
BEGIN
	DECLARE @xml XML;

	SELECT TOP(1) @xml = CAST([target_data] as XML)
	FROM sys.dm_xe_session_targets [t]
		INNER JOIN sys.dm_xe_sessions [s]
			ON  [t].[event_session_address] = [s].[address]
	WHERE [t].[target_name] = 'ring_buffer'
		AND [s].[name] = 'blocking';

	SELECT [timestamp_utc] = [n].[data].[value]('(@timestamp)[1]','DATETIME2')
		,[database_id] = [n].[data].[value]('(data[@name="database_id"]/value)[1]','INT')
		,[duration_ms] = [n].[data].[value]('(data[@name="duration"]/value)[1]','BIGINT')/1000
		,[blocked_process_id] = [n].[data].[value]('(//blocked-process/process/@id)[1]','NVARCHAR(128)')
		,[blocked_waitresource] = [n].[data].[value]('(//blocked-process/process/@waitresource)[1]','NVARCHAR(128)')
		,[blocked_spid] = [n].[data].[value]('(//blocked-process/process/@spid)[1]','SMALLINT')
		,[blocked_clientapp] = [n].[data].[value]('(//blocked-process/process/@clientapp)[1]','NVARCHAR(128)')
		,[blocked_hostname] = [n].[data].[value]('(//blocked-process/process/@hostname)[1]','NVARCHAR(128)')
		,[blocked_loginname] = [n].[data].[value]('(//blocked-process/process/@loginname)[1]','NVARCHAR(128)')
		,[blocked_inputbuf] = [n].[data].[value]('(//blocked-process/process/inputbuf/text())[1]','NVARCHAR(MAX)')
		,[blocking_status] = [n].[data].[value]('(//blocking-process/process/@status)[1]','NVARCHAR(128)')
		,[blocking_spid] = [n].[data].[value]('(//blocking-process/process/@spid)[1]','SMALLINT')
		,[blocking_clientapp] = [n].[data].[value]('(//blocking-process/process/@clientapp)[1]','NVARCHAR(128)')
		,[blocking_hostname] = [n].[data].[value]('(//blocking-process/process/@hostname)[1]','NVARCHAR(128)')
		,[blocking_loginname] = [n].[data].[value]('(//blocking-process/process/@loginname)[1]','NVARCHAR(128)')
		,[blocking_inputbuf] = [n].[data].[value]('(//blocking-process/process/inputbuf/text())[1]','NVARCHAR(MAX)')
		,[xml_blocked_report] = [n].[data].[query]('.')
	FROM @xml.nodes('//RingBufferTarget/event') AS [n]([data])
	WHERE [n].[data].[value]('@name','VARCHAR(4000)') = 'blocked_process_report'
END
