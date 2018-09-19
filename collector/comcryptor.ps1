Param(
    [string]$SqlServer = '.',
    [string]$EmailTo = 'user@domain.co.nz',
    [string]$EmailFrom = 'user@domain.co.nz',
    [string]$Smtp = 'smtp.domain.co.nz'
)

CD $PSScriptRoot

$SQLServer = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "SELECT @@SERVERNAME")[0]
[string]$secret = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "SELECT [value] FROM [_dbaid].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'")[0]
[string]$instanceTag = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "EXEC [_dbaid].[system].[get_instance_tag];")[0]
[string]$7zip = "$PSScriptRoot\7za.exe"
[string]$7zipArgs = "a -v10m -mx=9 -tzip -sdel -p'$secret'"
[string]$7zipSource = "$PSScriptRoot\*.xml" 
[string]$7zipTarget = $instanceTag + '_' + (Get-Date -Format 'yyyyMMddHHmmss') + '.zip'

$7zipCmd = "'$7zip' $7zipArgs '$7zipTarget' '$7zipSource'"

if ((Get-ChildItem -Path $7zipSource).Length -gt 0) {
    Invoke-Expression "&$7zipCmd"
} else {
    Write-Host 'No xml files in current directory. '
}

[string[]]$emailAttachements = (Get-ChildItem -Path "$PSScriptRoot\*.zip.[0-9][0-9][0-9]").FullName
[string]$emailBody = "collector results for: $SQLServer.$env:USERDNSDOMAIN"

if ($emailAttachements.Length -gt 0) {
    Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "collector" -Body $emailBody -Attachments $emailAttachements -SmtpServer $Smtp
    
    foreach ($item in $emailAttachements) {
        Remove-Item -Path $item -Force
    }
} else {
    Write-Host 'No zip files in current directory. '
}

# SIG # Begin signature block
# MIIFnQYJKoZIhvcNAQcCoIIFjjCCBYoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUsjefjNoA/DaTR1zwLBkgajjW
# xV+gggMzMIIDLzCCAhegAwIBAgIQIi8ovuNN07NB5ThYZrUt5TANBgkqhkiG9w0B
# AQsFADAfMR0wGwYDVQQDDBR3YXluZXRAZGF0YWNvbS5jby5uejAeFw0xODA5MTMw
# MzUxMjBaFw0xOTA5MTMwNDExMjBaMB8xHTAbBgNVBAMMFHdheW5ldEBkYXRhY29t
# LmNvLm56MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtHhtPAtrSCHY
# I10PEzEnVju5VjIMFzjJrjimhQwMGpjkVHWK+kMg18+wM8oY+hr6fOIyzAD/kZWY
# qOlmlb1PiKG/cqKk0B7dcAeDiGlKdzhmFP5tqzbzYNLmIlGlPlknjop3SW75LBZN
# RydiTbCZeRqwLCdw4xocyUbeA6ptzbPhhDuamVKl0+WW83LAAdnabQ/Om4mz4N7F
# sOlzxOG0kANpUX4hPiZjgc4AanrDM7IFtOD+mzn9/UaJ1tWsdVd9zDLTiDkYG1Ub
# b8ZSyln1IXQIV25caUHwYL/awcXTRo8dmwHPy9j4L9sPV/VOMe/Ght4s9+LfZwCJ
# X5NIzZzcXQIDAQABo2cwZTAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHwYDVR0RBBgwFoIUd2F5bmV0QGRhdGFjb20uY28ubnowHQYDVR0OBBYE
# FAlE3KmQeXvUv76jngfKtEWTg5FhMA0GCSqGSIb3DQEBCwUAA4IBAQAKmh1sIPxG
# +kzgsJl7wfTuoS4C2bM31T/H04e1yscI34BwSRi2IqAlD0e/F6/xEamh0EcXXiri
# Ge8uvSuHdU3OeilF2EuB8yhffDjQWQMojfesqmdRKHsLJ3jdbn2don+WhVT2YZww
# ccsQ3HxOay1j4SfpDFMADhWELx2kHgrVYr9mIMfzn4GaQreM5cDhcnNoQfrfeEKp
# jCS7Mtgx6JWUlnrOnCeepoihqurrn45CtgA9D2ilTw8CzaKIU1guLS1oxHbkRF1B
# qUaMwdweDGm1UdCYwP9OtU216PUwbQeHx05KKrTs7PuZixuoVz61nQBlj8WgZl+S
# u5hRrpRssGCXMYIB1DCCAdACAQEwMzAfMR0wGwYDVQQDDBR3YXluZXRAZGF0YWNv
# bS5jby5uegIQIi8ovuNN07NB5ThYZrUt5TAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUlAM11MYJ
# og2dXrw0+Br7UQmTAlgwDQYJKoZIhvcNAQEBBQAEggEAr8mE7qjC5sFWoVUpUb0E
# 6/D1SGolVTbejlKm9nPpyY1RML0fiR7E7XhLIIAzWHLPSL9Exh3DYKh2BNE6rHJt
# ZH2Th5Q48NFxQFUnV67oMASrACTK/WDCzn7u8Q9E58fHgXx/+DQajdE4JQxYSbBP
# /FxrqdlfQKohOO9hGCnVUlG0+Jgw+XllkgLcxL45QGFX52TZ455XIdyJD6gqrvyE
# TtsmmM4ngadQ09FGxBLLSdkrm9mbWlK3IHHN4YUKwz2jWB8K8xjPzWmeYsQS0wSj
# rXomkk3GiEXqKftmVIMN0s6SvpnqrAq6WFtQvBTXVL0M6AeF7qUHDnbcLPrrGsm7
# 6Q==
# SIG # End signature block
