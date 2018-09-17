[string]$SQLServer = '.'

[string]$secret = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "SELECT [value] FROM [_dbaid].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'")[0]

[string]$7zip = "$PSScriptRoot\7za.exe"
[string]$7zipArgs = "-mx=9 -tzip -sdel -p'$secret' a"
[string]$source = "$PSScriptRoot\*.xml" 
[string]$target = Join-Path $PSScriptRoot ((((Get-ChildItem -Path $PSScriptRoot -Filter *.xml).Name -split '_' `
    | Group-Object | Where { $_.Count -eq (Get-ChildItem -Path $PSScriptRoot -Filter *.xml).Length }).Name -join '_') `
    + "_$(Get-Date -Format 'yyyyMMddHHmmss').zip")

$cmd = "'$7zip' $7zipArgs '$target' '$source'"
Invoke-Expression "&$cmd"