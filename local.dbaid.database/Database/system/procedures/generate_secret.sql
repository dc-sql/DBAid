/*
Generates random secret with user defined length. 

PARAMETERS
	INPUT
		@length INT
		Length of the secret to generate. Default 20 characters. 
		
	OUTPUT
		@secret VARCHAR(100)
		Output parameter that contains the generated secret.  
*/

CREATE PROCEDURE [system].[generate_secret] (
	@length INT = 20,
	@secret VARCHAR(100) OUTPUT
)
WITH ENCRYPTION 
AS
BEGIN
	WHILE 1=1
	BEGIN
		DECLARE @char CHAR;
		SELECT @char = CHAR(CAST(ROUND((122-48)*RAND()+48,0) AS INT)) OPTION(RECOMPILE);
		SELECT @secret = CONCAT(@secret, @char);

		IF (LEN(@secret) >= @length)
			BREAK;
		ELSE
			CONTINUE;
	END

	SELECT [secret]=@secret;
END
GO