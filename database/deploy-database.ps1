## Requires SQLPACKAGE.exe
## https://docs.microsoft.com/en-us/sql/tools/sqlpackage-download

Param(
    [parameter(Mandatory=$true)]
    [string]$SQLServer
)

CD $PSScriptRoot
&"C:\Program Files\Microsoft SQL Server\140\DAC\bin\SqlPackage.exe" /Action:Publish /SourceFile:dbaid-release.dacpac /TargetServerName:"$SQLServer" /TargetDatabaseName:_dbaid /Variables:Version=10.0

if (!$psISE) {
	Write-Host -NoNewLine 'Press any key to continue...';
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}