CREATE TYPE [dbo].[udtt_service_property] AS TABLE
(
	[class_object] NVARCHAR(300) NOT NULL,
	[property] NVARCHAR(128) NOT NULL,
	[value] SQL_VARIANT NULL
)
