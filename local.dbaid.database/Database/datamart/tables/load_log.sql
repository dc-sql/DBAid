/*



*/

CREATE TABLE [datamart].[load_log]
(
	[load_date] DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
	[load_type] NVARCHAR(512) NOT NULL,
)
