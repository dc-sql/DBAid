CREATE PROCEDURE [configg].[get_cis_benchmark]
WITH ENCRYPTION
AS
BEGIN
	SELECT 'AUDIT' AS [heading], 'CIS Benchmark' AS [subheading], '' AS [comment]

	EXEC [audit].[get_cis_benchmark]
END
