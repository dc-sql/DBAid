/*



*/

CREATE FUNCTION [system].[get_clean_string](@dirty_string NVARCHAR(MAX))
RETURNS TABLE
WITH ENCRYPTION
RETURN(
	SELECT 
	LTRIM(
		RTRIM(
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(@dirty_string,'  ',' ')
							,'  ', ' ')
						,CHAR(9),'')
					,CHAR(10),'')
				,CHAR(13),'')
			,'","','";"')
		)
	) AS [clean_string]
)

