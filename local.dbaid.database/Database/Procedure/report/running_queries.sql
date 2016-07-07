/*
Copyright (C) 2016 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [report].[running_queries]
WITH ENCRYPTION
AS
BEGIN

	SELECT
		[request].[session_id],
		[request].[request_id] AS [session_request_id],
		[request].[status], 
		[request].[percent_complete],
		[session].[host_name],
		[connection].[client_net_address],
		CASE 
			WHEN [session].[login_name] = [session].[original_login_name]
			THEN [session].[login_name]
			ELSE [session].[login_name] + N' (' + [session].[original_login_name] + N')' 
		END AS [login_name],
		[session].[program_name],
		DB_NAME([request].[database_id]) AS [database_name],
		[request].[command],
		SUBSTRING(
			[sqltext].[text], 
			[request].[statement_start_offset] / 2, 
			(CASE 
				WHEN [request].[statement_end_offset] = -1 
				THEN LEN(CONVERT(NVARCHAR(MAX), [sqltext].[text])) * 2 
				ELSE [request].[statement_end_offset] END - [request].[statement_start_offset]
			) 
		/ 2) AS [statement],
		[sqltext].[text] AS [query_text], 
		[queryplan].[query_plan] AS [xml_query_plan],
		[request].[start_time],
		[request].[total_elapsed_time] AS [total_elapsed_time_ms],
		[request].[cpu_time] AS [cpu_time_ms],
		[request].[wait_type] AS [current_wait_type],
		[request].[wait_resource] AS [current_wait_resource],
		[request].[wait_time] AS [current_wait_time_ms],
		[request].[last_wait_type],
		[request].[blocking_session_id],
		[request].[reads],
		[request].[writes],
		[request].[logical_reads],
		[request].[row_count],
		[request].[prev_error],
		[request].[nest_level],
		[request].[granted_query_memory],
		[request].[executing_managed_code],
		[request].[transaction_id],
		[request].[open_transaction_count],
		[request].[open_resultset_count],
		[request].[scheduler_id],
		[request].[quoted_identifier],
		[request].[arithabort],
		[request].[ansi_null_dflt_on],
		[request].[ansi_defaults],
		[request].[ansi_warnings],
		[request].[ansi_padding],
		[request].[ansi_nulls],
		[request].[concat_null_yields_null],
		CASE [request].[transaction_isolation_level]
			WHEN 0 THEN N'Unspecified'
			WHEN 1 THEN N'ReadUncomitted'
			WHEN 2 THEN N'ReadCommitted'
			WHEN 3 THEN N'Repeatable'
			WHEN 4 THEN N'Serializable'
			WHEN 5 THEN N'Snapshot'
			ELSE CAST([request].[transaction_isolation_level] AS NVARCHAR(32))
		END AS [transaction_isolation_level_name],
		[request].[lock_timeout],
		[request].[deadlock_priority],
		[request].[context_info]
	FROM
		[sys].[dm_exec_requests] AS [request]
			LEFT OUTER JOIN [sys].[dm_exec_sessions] AS [session] 
				ON [session].[session_id] = [request].[session_id]
			LEFT OUTER JOIN [sys].[dm_exec_connections] AS [connection] 
				ON [connection].[connection_id] = [request].[connection_id]
			CROSS APPLY [sys].[dm_exec_sql_text]([request].[sql_handle]) AS [sqltext] 
			CROSS APPLY [sys].[dm_exec_query_plan]([request].[plan_handle]) AS [queryplan]
	WHERE
		[request].[status] NOT IN (N'Background',N'Sleeping') 
		AND [request].[session_id] <> @@SPID
	ORDER BY 
		[request].[start_time];
END
GO
