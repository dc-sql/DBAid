/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [log].[job_history]
(
	@start_datetime DATETIME = NULL,
	@end_datetime DATETIME = NULL,
	@sanitize BIT = 0,
	@update_last_execution_datetime BIT = 0
)
WITH ENCRYPTION, EXECUTE AS 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @report_datetime DATETIME;

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
	
	IF (@start_datetime IS NULL)
	BEGIN
		SELECT @start_datetime=ISNULL([last_execution_datetime], DATEADD(DAY,-1,GETDATE())) 
		FROM [setting].[procedure_list] WHERE [procedure_id] = @@PROCID;
	END

	INSERT INTO @jobhistory 
		EXEC [msdb].[dbo].[sp_help_jobhistory] @mode=N'FULL'

	SET @report_datetime = GETDATE();

	IF (@end_datetime IS NULL)
		SET @end_datetime = @report_datetime;

	;WITH JobHistory
	AS
	(
		SELECT [H].[job_name]
			,[H].[step_id]
			,[H].[step_name]
			,CASE 
				WHEN @sanitize=0 THEN 
					CASE 
						WHEN [H].[run_status]=0 THEN [H].[message] 
						ELSE NULL
					END
				ELSE ISNULL([M].[text],'SANITIZE_DATASET is enabled. Please investigate on the SQL Instance.') 
			END AS [error_message]
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
	SELECT [I].[guid] AS [instance_guid]
		,[D1].[date] AS [run_datetime]
		,[job_name]
		,[step_id]
		,[step_name]
		,[E].[string] AS [error_message]
		,[run_status]
		,[run_duration_sec]
	FROM [JobHistory] [H]
		CROSS APPLY [get].[instance_guid]() [I]
		CROSS APPLY [get].[clean_string]([error_message]) [E]
		CROSS APPLY [get].[datetime_with_offset]([H].[run_datetime]) [D1]
	WHERE [run_datetime] BETWEEN @start_datetime AND @end_datetime
	ORDER BY [H].[run_datetime];

	IF (@update_last_execution_datetime = 1)
		UPDATE [setting].[procedure_list] SET [last_execution_datetime] = @end_datetime WHERE [procedure_id] = @@PROCID;
END;