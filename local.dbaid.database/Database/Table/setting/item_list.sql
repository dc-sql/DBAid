CREATE TABLE [setting].[item_list]
(
	[item_id] INT IDENTITY PRIMARY KEY, 
    [item_name] NVARCHAR(128) NOT NULL, 
    [item_type] VARCHAR(50) NULL, 
    [is_enabled] BIT NOT NULL DEFAULT 1, 
    CONSTRAINT [CK_item_list_item_type] CHECK ([item_type] IN ('db', 'job'))
)
