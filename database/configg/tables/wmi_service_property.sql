CREATE TABLE [configg].[wmi_service_property]
(
	[class] VARCHAR(128) NOT NULL, 
    [property] VARCHAR(128) NOT NULL, 
    [value] SQL_VARIANT NULL, 
    CONSTRAINT [PK_service_properties] PRIMARY KEY ([class], [property])
)
