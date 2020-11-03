$Root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

$Release = Get-ChildItem -Path $Root -Filter "*dbaid*.sql"

[array]$RelContent = $(Get-Content $Release) -replace "dbaid.warehouse", "_dbaid_warehouse" -replace "COLLATE Latin1_General_CI_AS", "";

$RelContent | Set-Content $Release
