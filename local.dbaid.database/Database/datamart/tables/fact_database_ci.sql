/*



*/

CREATE TABLE [datamart].[fact_database_ci]
(
	[fact_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[instance_id] INT NOT NULL,
	[database_id] INT NOT NULL,
	[date_id] INT NOT NULL,
	[time_id] INT NOT NULL,
	[property] NVARCHAR(128) NOT NULL,
	[value] SQL_VARIANT NOT NULL
)
