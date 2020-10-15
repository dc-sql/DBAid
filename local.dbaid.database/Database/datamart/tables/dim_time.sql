/*



*/

CREATE TABLE [datamart].[dim_time]
(
	[time_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[time] TIME(0) NOT NULL UNIQUE,
	[hour] TINYINT NOT NULL CONSTRAINT [ck_dim_time_hour] CHECK ([hour] BETWEEN 0 AND 24),
	[minute] TINYINT NOT NULL CONSTRAINT [ck_dim_time_minute] CHECK ([minute] BETWEEN 0 AND 60),
	[second] TINYINT NOT NULL CONSTRAINT [ck_dim_time_second] CHECK ([second] BETWEEN 0 AND 60),
	[timezone_offset] SMALLINT NULL CONSTRAINT [ck_dim_time_timezone_offset] CHECK ([timezone_offset] BETWEEN -720 AND 840)
)

GO

CREATE INDEX [IX_dim_time_time] ON [datamart].[dim_time] ([time])
