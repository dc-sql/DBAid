SET NOCOUNT ON;

SELECT 'INSTANCE' AS [heading], 'Maintenance Plans' AS [subheading], '' AS [comment]

SELECT [P].[name] AS [plan_name]
	,[plan_description].[clean_string] AS [plan_description]
	,[S].[subplan_name]
	,[subplan_description].[clean_string] AS [subplan_description]
	,[J].[job_id]
	,[J].[name] AS [job_name]
	,[P].[owner]
	,[P].[create_date]
FROM [msdb].[dbo].[sysmaintplan_plans] [P]
	INNER JOIN [msdb].[dbo].[sysmaintplan_subplans] [S]
		ON [P].[id] = [S].[plan_id]
	INNER JOIN [msdb].[dbo].[sysjobs] [J]
		ON [S].[job_id] = [J].[job_id]
	CROSS APPLY (SELECT 
					LTRIM(
						RTRIM(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE([P].[description],'  ',' ')
											,'  ', ' ')
										,CHAR(9),'')
									,CHAR(10),'')
								,CHAR(13),'')
							,'","','";"')
						)
					) AS [clean_string]
	) [plan_description]
	CROSS APPLY (SELECT 
					LTRIM(
						RTRIM(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE([S].[subplan_description],'  ',' ')
											,'  ', ' ')
										,CHAR(9),'')
									,CHAR(10),'')
								,CHAR(13),'')
							,'","','";"')
						)
					) AS [clean_string]
	) [subplan_description]