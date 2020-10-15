/*



*/

CREATE TABLE [datamart].[get_errorlog_history]
(
	[instance_guid] UNIQUEIDENTIFIER NULL,
	[log_date] DATETIMEOFFSET NULL,
	[source] NVARCHAR(100) NULL,
	[message_header] NVARCHAR(MAX) NULL,
	[message] NVARCHAR(MAX) NULL
)
