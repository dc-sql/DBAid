/*



*/

CREATE TABLE [system].[configuration] (
    [key] VARCHAR(128) NOT NULL,
    [value] SQL_VARIANT NULL,
    UNIQUE NONCLUSTERED ([key] ASC)
);
GO