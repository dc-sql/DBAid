CREATE TABLE [configg].[service_properties]
(
	[class] VARCHAR(128) NOT NULL PRIMARY KEY, 
    [property] VARCHAR(128) NOT NULL, 
    [value] SQL_VARIANT NULL, 
)
