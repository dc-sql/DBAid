/*
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
*/

CREATE TABLE [datamart].[dim_date]
(
	[date_id] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[date] DATE NOT NULL UNIQUE,
	[year] SMALLINT NOT NULL CONSTRAINT [ck_dim_date_year] CHECK ([year] BETWEEN 1900 AND 2050),
	[month] TINYINT NOT NULL CONSTRAINT [ck_dim_date_month] CHECK ([month] BETWEEN 1 AND 12),
	[day] TINYINT NOT NULL CONSTRAINT [ck_dim_date_day] CHECK ([day] BETWEEN 1 AND 31),
	[day_name] VARCHAR(9) NOT NULL CONSTRAINT [ck_dim_date_day_name] CHECK ([day_name] IN ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')),
	[quarter] TINYINT NOT NULL CONSTRAINT [ck_dim_date_quarter] CHECK ([quarter] BETWEEN 1 AND 4),
	[end_of_month] DATE NOT NULL
)

GO

CREATE INDEX [IX_dim_date_date] ON [datamart].[dim_date] ([date])
