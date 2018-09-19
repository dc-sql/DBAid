CREATE TABLE [dbo].[Queue](
  [QueueID] [int] IDENTITY(1,1) NOT NULL,
  [SchemaName] [sysname] NOT NULL,
  [ObjectName] [sysname] NOT NULL,
  [Parameters] [nvarchar](max) NOT NULL,
  [QueueStartTime] [datetime] NULL,
  [SessionID] [smallint] NULL,
  [RequestID] [int] NULL,
  [RequestStartTime] [datetime] NULL,
 CONSTRAINT [PK_Queue] PRIMARY KEY CLUSTERED
(
  [QueueID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
)
