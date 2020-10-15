/*



*/

CREATE PROCEDURE [collector].[get_agentjob_history]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@sanitise BIT = NULL,
	@update_execution_timestamp BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @jobhistory TABLE ([instance_id] INT
		,[job_id] UNIQUEIDENTIFIER
		,[job_name] NVARCHAR(128)
		,[step_id] INT
		,[step_name] NVARCHAR(128)
		,[sql_message_id] INT
		,[sql_severity] INT
		,[message] NVARCHAR(4000)
		,[run_status] INT
		,[run_date] INT
		,[run_time] INT
		,[run_duration] INT
		,[operator_emailed] NVARCHAR(128)
		,[operator_netsent] NVARCHAR(128)
		,[operator_paged] NVARCHAR(128)
		,[retries_attempted] INT
		,[server] NVARCHAR(128));
	
	IF (@sanitise IS NULL)
		SELECT @sanitise=CAST([value] AS BIT) FROM [system].[configuration] WHERE [key] = 'SANITISE_COLLECTOR_DATA';

	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=ISNULL([last_execution], DATEADD(DAY,-1,GETDATE())) 
		FROM [collector].[last_execution] WHERE [object_name] = OBJECT_NAME(@@PROCID);
	END

	IF (@end_datetime IS NULL)
		SET @end_datetime = GETDATE();

	INSERT INTO @jobhistory 
		EXEC [msdb].[dbo].[sp_help_jobhistory] @mode=N'FULL'

	;WITH JobHistory
	AS
	(
		SELECT [H].[job_name]
			,[H].[step_id]
			,[H].[step_name]
			,CASE WHEN @sanitise = 0 
				THEN CASE WHEN [H].[run_status] = 0 THEN [H].[message] ELSE NULL END
				ELSE [M].[text]	END AS [error_message]
			,CASE [H].[run_status] 
				WHEN 0 THEN 'Failed'
				WHEN 1 THEN 'Succeeded'
				WHEN 2 THEN 'Retry (step only)'
				WHEN 3 THEN 'Canceled'
				WHEN 4 THEN 'In-Progress'
				WHEN 5 THEN 'Unknown' 
				ELSE 'Unknown' END AS [run_status]
			,CAST(CAST([H].[run_date] AS CHAR(8)) + ' ' + STUFF(STUFF(REPLACE(STR([H].[run_time],6,0),' ','0'),3,0,':'),6,0,':') AS DATETIME) AS [run_datetime]
			,(([H].[run_duration]/10000 * 3600) + (([H].[run_duration]%10000)/100*60) + ([H].[run_duration]%10000)%100) AS [run_duration_sec]
		FROM @jobhistory [H]
			LEFT JOIN [master].[sys].[messages] [M]
				ON [M].[language_id] = CAST(SERVERPROPERTY('LCID') AS INT)
					AND [H].[sql_message_id] = [M].[message_id]
		WHERE [H].[run_status] NOT IN (1, 4)
	) 
	SELECT [I].[instance_guid]
		,[D1].[datetimeoffset] AS [run_datetime]
		,[H].[job_name]
		,[H].[step_id]
		,[H].[step_name]
		,[E].[clean_string] AS [error_message]
		,[H].[run_status]
		,[H].[run_duration_sec]
	FROM [JobHistory] [H]
		CROSS APPLY [system].[get_instance_guid]() [I]
		CROSS APPLY [system].[get_clean_string]([H].[error_message]) [E]
		CROSS APPLY [system].[get_datetimeoffset]([H].[run_datetime]) [D1]
	WHERE [H].[run_datetime] BETWEEN @start_datetime AND @end_datetime
	ORDER BY [H].[run_datetime];

	IF (@update_execution_timestamp = 1)
		MERGE INTO [collector].[last_execution] AS [Target]
		USING (SELECT OBJECT_NAME(@@PROCID), @end_datetime) AS [Source]([object_name],[last_execution])
		ON [Target].[object_name] = [Source].[object_name]
		WHEN MATCHED THEN
			UPDATE SET [Target].[last_execution] = [Source].[last_execution]
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT ([object_name],[last_execution]) VALUES ([Source].[object_name],[Source].[last_execution]);
END;