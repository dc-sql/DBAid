USE [_dbaid]
GO

DISABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE;
GO

DISABLE TRIGGER [trg_stop_staticparameter_change] ON [dbo].[static_parameters];
GO

UPDATE [_dbaid].[dbo].[static_parameters] SET [value] = N'public key xml'
WHERE [name] = N'PUBLIC_ENCRYPTION_KEY'
GO

ENABLE TRIGGER [trg_stop_staticparameter_change] ON [dbo].[static_parameters];
GO

ENABLE TRIGGER [trg_stop_ddl_modification] ON DATABASE;
GO