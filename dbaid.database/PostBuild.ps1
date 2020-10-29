<#
Copyright (C) 2015 Datacom
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
#>
$Root = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

$Release = Get-ChildItem -Path $Root -Filter "*dbaid*.sql"
$PreUpgrade = $Root + "\PreUpgrade.sql"

[array]$PreContent = Get-Content $PreUpgrade;
[array]$RelContent = $(Get-Content $Release) -replace "local.dbaid.database", "_dbaid" -replace "COLLATE Latin1_General_CI_AS", "";
[int]$PreIndex = $([array]::IndexOf($RelContent, ":on error exit")) + 1;
[array]$Output = $RelContent[0..$PreIndex],$PreContent,$RelContent[$PreIndex..($RelContent.Length -1)]

$Output | Set-Content $Release