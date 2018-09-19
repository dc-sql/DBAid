CREATE TABLE [dbo].[QueueDatabase](
  [QueueID] [int] NOT NULL,
  [DatabaseName] [sysname] NOT NULL,
  [DatabaseOrder] [int] NULL,
  [DatabaseStartTime] [datetime] NULL,
  [DatabaseEndTime] [datetime] NULL,
  [SessionID] [smallint] NULL,
  [RequestID] [int] NULL,
  [RequestStartTime] [datetime] NULL,
 CONSTRAINT [PK_QueueDatabase] PRIMARY KEY CLUSTERED
(
  [QueueID] ASC,
  [DatabaseName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)

,CONSTRAINT [FK_QueueDatabase_Queue] FOREIGN KEY([QueueID])
REFERENCES [dbo].[Queue] ([QueueID]))
