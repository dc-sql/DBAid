SET NOCOUNT ON;

SELECT 'SQL AGENT' AS [heading], 'Jobs' AS [subheading], 'This is a list of all Agent jobs on the instance' AS [comment]

SELECT [JO].[job_id]
	,[JO].[name] AS [job_name]
	,SUSER_SNAME([JO].[owner_sid]) AS [job_owner]
	,[JO].[enabled] AS [job_enabled]
	,[job_desc].[clean_string] AS [job_desc]
	,CAST((SELECT [step].[step_id] AS [@stepid]
			,[step].[step_name] AS [@step_name]
			,[step].[subsystem] AS [@subsystem]
			,[step].[database_name] AS [@database_name]
			,CASE WHEN [step].[subsystem] = 'TSQL' THEN [step].[database_user_name]
				ELSE [proxy].[name] END AS [@execute_as]
			,[credential].[name] AS [@proxy_credential]
			,[credential].[credential_identity] AS [@credential_identity]
			,[step].[command] AS [codeblock]
		FROM [msdb].[dbo].[sysjobs] [job]
			LEFT JOIN [msdb].[dbo].[sysjobsteps] [step]
				ON [job].[job_id] = [step].[job_id]
			LEFT JOIN msdb.dbo.sysproxies [proxy]
				ON [step].[proxy_id] = [proxy].[proxy_id]
			LEFT JOIN sys.credentials [credential]
				ON [proxy].[credential_id] = [credential].[credential_id]
		WHERE [job].[job_id] = [JO].[job_id]
		ORDER BY [step].[step_id]
		FOR XML PATH('row'), ROOT('table')) AS XML) AS [step_details]
	,[SOE].[name] AS [notify_email_operator]
	,[SON].[name] AS [notify_netsend_operator]
	,[SOP].[name] AS [notify_page_operator]
	,[JO].[date_created] AS [job_created]
	,CASE WHEN [JO].[date_created] = [JO].[date_modified] THEN NULL ELSE [JO].[date_modified] END AS [job_modified]
	,CAST([SD].[schedule_detail] AS XML) AS [schedule_detail]
FROM [msdb].[dbo].[sysjobs] [JO]
	LEFT JOIN [msdb].[dbo].[sysoperators] [SOE]
		ON [JO].[notify_email_operator_id] = [SOE].[id]
			AND [SOE].[enabled] = 1
	LEFT JOIN [msdb].[dbo].[sysoperators] [SON]
		ON [JO].[notify_netsend_operator_id] = [SON].[id]
			AND [SON].[enabled] = 1
	LEFT JOIN [msdb].[dbo].[sysoperators] [SOP]
		ON [JO].[notify_page_operator_id] = [SOP].[id]
			AND [SOP].[enabled] = 1
	CROSS APPLY (SELECT 
					LTRIM(
						RTRIM(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE([JO].[description],'  ',' ')
											,'  ', ' ')
										,CHAR(9),'')
									,CHAR(10),'')
								,CHAR(13),'')
							,'","','";"')
						)
					) AS [clean_string]
	) [job_desc]
	CROSS APPLY (SELECT(SELECT [S].[enabled] AS [@schedule_enabled]
	,CASE
		WHEN [J].[job_id] IS NULL THEN 'Unscheduled'
		WHEN [S].[schedule_id] IS NULL THEN 'Unscheduled'
		WHEN [S].[freq_type] = 1 THEN 'Once on '
				+ CONVERT(CHAR(10), CAST(CAST( [S].[active_start_date] AS VARCHAR ) AS DATETIME), 102) /*yyyy.mm.dd*/
		WHEN [S].[freq_type] = 4 THEN 'Daily'
		WHEN [S].[freq_type] = 8 THEN 
			CASE WHEN [S].[freq_recurrence_factor] = 1 THEN 'Weekly on '
				WHEN [S].[freq_recurrence_factor] > 1 THEN 'Every '
					+ CAST( [S].[freq_recurrence_factor] AS VARCHAR )
					+ ' weeks on ' END
			+ LEFT(CASE WHEN [S].[freq_interval] & 1 = 1 THEN 'Sunday, ' ELSE '' END
				+ CASE WHEN [S].[freq_interval] & 2 = 2 THEN 'Monday, ' ELSE '' END
				+ CASE WHEN [S].[freq_interval] & 4 = 4 THEN 'Tuesday, ' ELSE '' END
				+ CASE WHEN [S].[freq_interval] & 8 = 8 THEN 'Wednesday, ' ELSE '' END
				+ CASE WHEN [S].[freq_interval] & 16 = 16 THEN 'Thursday, ' ELSE '' END
				+ CASE WHEN [S].[freq_interval] & 32 = 32 THEN 'Friday, ' ELSE '' END
				+ CASE WHEN [S].[freq_interval] & 64 = 64 THEN 'Saturday, ' ELSE '' END
				, LEN(CASE WHEN [S].[freq_interval] & 1 = 1 THEN 'Sunday, ' ELSE '' END
					+ CASE WHEN [S].[freq_interval] & 2 = 2 THEN 'Monday, ' ELSE '' END
					+ CASE WHEN [S].[freq_interval] & 4 = 4 THEN 'Tuesday, ' ELSE '' END
					+ CASE WHEN [S].[freq_interval] & 8 = 8 THEN 'Wednesday, ' ELSE '' END
					+ CASE WHEN [S].[freq_interval] & 16 = 16 THEN 'Thursday, ' ELSE '' END
					+ CASE WHEN [S].[freq_interval] & 32 = 32 THEN 'Friday, ' ELSE '' END
					+ CASE WHEN [S].[freq_interval] & 64 = 64 THEN 'Saturday, ' ELSE '' END
					) - 1 -- LEN() ignores trailing spaces
				)
		WHEN [S].[freq_type] = 16 THEN
			CASE WHEN [S].[freq_recurrence_factor] = 1 THEN 'Monthly on the '
				WHEN [S].[freq_recurrence_factor] > 1 THEN 'Every '
					+ CAST( [S].[freq_recurrence_factor] AS VARCHAR )
					+ ' months on the ' END
			+ CAST([S].[freq_interval] AS VARCHAR)
			+ CASE WHEN [S].[freq_interval] IN (1, 21, 31) THEN 'st'
				WHEN [S].[freq_interval] IN (2, 22) THEN 'nd'
				WHEN [S].[freq_interval] IN (3, 23) THEN 'rd'
				ELSE 'th' END
		WHEN [S].[freq_type] = 32 THEN
			CASE WHEN [S].[freq_recurrence_factor] = 1 THEN 'Monthly on the '
				WHEN [S].[freq_recurrence_factor] > 1 THEN 'Every '
					+ CAST( [S].[freq_recurrence_factor] AS VARCHAR )
					+ ' months on the ' END
			+ CASE [S].[freq_relative_interval]
				WHEN 0x01 THEN 'first '
				WHEN 0x02 THEN 'second '
				WHEN 0x04 THEN 'third '
				WHEN 0x08 THEN 'fourth '
				WHEN 0x10 THEN 'last ' END
			+ CASE [S].[freq_interval]
				WHEN 1 THEN 'Sunday'
				WHEN 2 THEN 'Monday'
				WHEN 3 THEN 'Tuesday'
				WHEN 4 THEN 'Wednesday'
				WHEN 5 THEN 'Thursday'
				WHEN 6 THEN 'Friday'
				WHEN 7 THEN 'Saturday'
				WHEN 8 THEN 'day'
				WHEN 9 THEN 'week day'
				WHEN 10 THEN 'weekend day' END
		WHEN [S].[freq_type] = 64 THEN 'Automatically starts when SQLServerAgent starts.'
		WHEN [S].[freq_type] = 128 THEN 'Starts whenever the CPUs become idle'
		ELSE '' END
	+ CASE
		WHEN [J].[job_id] IS NULL THEN ''
		WHEN [S].[freq_subday_type] = 1 OR [S].[freq_type] = 1
			THEN ' at ' 
				+ CASE -- Depends on time being integer to drop right-side digits
					WHEN([S].[active_start_time] % 1000000)/10000 = 0 THEN '12'
						+ ':' 
						+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100)))
						+ CONVERT(char(2),([S].[active_start_time] % 10000)/100) 
						+ ' AM'
					WHEN ([S].[active_start_time] % 1000000)/10000< 10 then
						CONVERT(char(1),([S].[active_start_time] % 1000000)/10000) 
						+ ':' 
						+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
						+ CONVERT(char(2),([S].[active_start_time] % 10000)/100) 
						+ ' AM'
					WHEN ([S].[active_start_time] % 1000000)/10000 < 12 then
						CONVERT(char(2),([S].[active_start_time] % 1000000)/10000) 
						+ ':' 
						+REPLICATE('0',2 - LEN(convert(char(2),([S].[active_start_time] % 10000)/100))) 
						+ CONVERT(char(2),([S].[active_start_time] % 10000)/100) 
						+ ' AM'
					WHEN ([S].[active_start_time] % 1000000)/10000< 22 then
						CONVERT(char(1),(([S].[active_start_time] % 1000000)/10000) - 12) 
						+ ':' 
						+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
						+ CONVERT(char(2),([S].[active_start_time] % 10000)/100) 
						+ ' PM'
					ELSE CONVERT(char(2),(([S].[active_start_time] % 1000000)/10000) - 12)
						+ ':' 
						+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
						+ CONVERT(char(2),([S].[active_start_time] % 10000)/100) 
						+ ' PM' END
		WHEN [S].[freq_subday_type] IN (2, 4, 8)
			THEN ' every '
				+ CAST( [S].[freq_subday_interval] AS VARCHAR )
				+ CASE [S].[freq_subday_type]
					WHEN 2 THEN ' second'
					WHEN 4 THEN ' minute'
					WHEN 8 THEN ' hour' END
				+ CASE
					WHEN [S].[freq_subday_interval] > 1 THEN 's'
					ELSE '' END
		ELSE '' END
	+ CASE
		WHEN [J].[job_id] IS NULL THEN ''
		WHEN [S].[freq_subday_type] IN (2, 4, 8) THEN ' between '
			+ CASE -- Depends on time being integer to drop right-side digits
				WHEN([S].[active_start_time] % 1000000)/10000 = 0 THEN '12' + ':' 
					+ REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100)))
					+ RTRIM(CONVERT(char(2),([S].[active_start_time] % 10000)/100))
					+ ' AM'
				WHEN ([S].[active_start_time] % 1000000)/10000< 10 THEN
					CONVERT(char(1),([S].[active_start_time] % 1000000)/10000) 
					+ ':' 
					+ REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_start_time] % 10000)/100))
					+ ' AM'
				WHEN ([S].[active_start_time] % 1000000)/10000 < 12 THEN
					CONVERT(char(2),([S].[active_start_time] % 1000000)/10000) 
					+ ':' 
					+ REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_start_time] % 10000)/100)) 
					+ ' AM'
				WHEN ([S].[active_start_time] % 1000000)/10000< 22 THEN
						CONVERT(char(1),(([S].[active_start_time] % 1000000)/10000) - 12) 
					+ ':' 
					+ REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_start_time] % 10000)/100)) 
					+ ' PM'
				ELSE CONVERT(char(2),(([S].[active_start_time] % 1000000)/10000) - 12)
					+ ':' 
					+ REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_start_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_start_time] % 10000)/100))
					+ ' PM' END
			+ ' and '
			+ CASE -- Depends on time being integer to drop right-side digits
				WHEN([S].[active_end_time] % 1000000)/10000 = 0 THEN '12' + ':' 
					+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_end_time] % 10000)/100)))
					+ RTRIM(CONVERT(char(2),([S].[active_end_time] % 10000)/100))
					+ ' AM'
				WHEN ([S].[active_end_time] % 1000000)/10000< 10 THEN
					CONVERT(char(1),([S].[active_end_time] % 1000000)/10000) 
					+ ':' 
					+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_end_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_end_time] % 10000)/100))
					+ ' AM'
				WHEN ([S].[active_end_time] % 1000000)/10000 < 12 THEN
					CONVERT(char(2),([S].[active_end_time] % 1000000)/10000) 
					+ ':' 
					+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_end_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_end_time] % 10000)/100))
					+ ' AM'
				WHEN ([S].[active_end_time] % 1000000)/10000< 22 THEN
					CONVERT(char(1),(([S].[active_end_time] % 1000000)/10000) - 12)
					+ ':' 
					+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_end_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_end_time] % 10000)/100)) 
					+ ' PM'
				ELSE CONVERT(char(2),(([S].[active_end_time] % 1000000)/10000) - 12)
					+ ':' 
					+REPLICATE('0',2 - LEN(CONVERT(char(2),([S].[active_end_time] % 10000)/100))) 
					+ RTRIM(CONVERT(char(2),([S].[active_end_time] % 10000)/100)) 
					+ ' PM' END
			ELSE '' END AS [@schedule_desc]
			,[S].[date_created] AS [@schedule_created]
			,CASE WHEN [S].[date_created] = [S].[date_modified] THEN NULL ELSE [S].[date_modified] END AS [@schedule_modified]
FROM [msdb].[dbo].[sysjobs] [J]
	LEFT JOIN [msdb].[dbo].[sysjobschedules] [JS] 
		ON [J].[job_id] = [JS].[job_id] 
	LEFT JOIN [msdb].[dbo].[sysschedules] [S]
		ON [JS].[schedule_id] = [S].[schedule_id]
WHERE [J].[job_id] = [JO].[job_id]
FOR XML PATH('row'), ROOT('table')) AS [schedule_detail]) [SD]