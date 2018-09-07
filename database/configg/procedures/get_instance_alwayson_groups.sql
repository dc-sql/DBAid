/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE PROCEDURE [configg].[get_instance_alwayson_groups]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF SERVERPROPERTY('IsHadrEnabled') IS NOT NULL
	BEGIN
		EXEC sp_executesql @stmt = N'SELECT [AG].[name] AS [ag_name]
										,[AG].[failure_condition_level]
										,[AG].[health_check_timeout]
										,[AG].[automated_backup_preference_desc] AS [automated_backup_preference]
										,[DB].[databases] AS [ag_databases]
										,CAST([AR].[availability_replicas] AS XML) AS [availability_replicas]
										,[DNS].[dns_name] AS [listener_dns]
										,[DNS].[port] AS [listener_port]
										,CAST([IP].[listener_ip_addresses] AS XML) AS [listener_ip_addresses]
									FROM [sys].[availability_groups] [AG]
										LEFT JOIN [sys].[dm_hadr_name_id_map] [ID]
											ON [AG].[resource_id] = [ID].[ag_resource_id]
										LEFT JOIN [sys].[availability_group_listeners] [DNS]
											ON [AG].[group_id] = [DNS].[group_id]
										CROSS APPLY (SELECT STUFF((SELECT '', '' + QUOTENAME([database_name]) FROM [sys].[availability_databases_cluster] WHERE [group_id] = [AG].[group_id] FOR XML PATH('''')),1,2,'''') AS [databases]) [DB]
										CROSS APPLY (SELECT (SELECT [A].[replica_server_name]
																	,[A].[endpoint_url]
																	,[A].[availability_mode_desc]
																	,[A].[failover_mode_desc]
																	,[A].[session_timeout]
																	,[A].[primary_role_allow_connections_desc]
																	,[A].[secondary_role_allow_connections_desc]
																	,[A].[create_date]
																	,[A].[backup_priority]
																	,[A].[read_only_routing_url] 
																FROM [sys].[availability_replicas] [A]
																WHERE [A].[group_id] = [ID].[ag_id]
																FOR XML PATH(''replica''), ROOT(''table'')) AS [availability_replicas]) [AR]
										CROSS APPLY (SELECT (SELECT [ip_address]
																	,[ip_subnet_mask]
																	,[is_dhcp]
																	,[network_subnet_ip]
																	,[network_subnet_prefix_length]
																	,[network_subnet_ipv4_mask]
																FROM [sys].[availability_group_listener_ip_addresses]
																WHERE [listener_id] = [DNS].[listener_id]
																FOR XML PATH(''ip'')) AS [listener_ip_addresses]) [IP]';
	END
END
