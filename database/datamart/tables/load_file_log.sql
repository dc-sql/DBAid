CREATE TABLE [datamart].[load_file_log]
(
	[load_date] DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	[file_name] NVARCHAR(260) NULL,
)
