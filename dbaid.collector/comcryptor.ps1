Param(
    [string]$SqlServer = '.',
    [string]$EmailTo = 'user@domain.co.nz',
    [string]$EmailFrom = 'user@domain.co.nz',
    [string]$Smtp = 'smtp.domain.co.nz',
    [Switch]$EmailEnable
)

Set-Location $PSScriptRoot

$SQLServer = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "SELECT @@SERVERNAME")[0]
[string]$secret = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "SELECT [value] FROM [_dbaid].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'")[0]
[string]$instanceTag = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "EXEC [_dbaid].[system].[get_instance_tag];")[0]
[string]$7zip = "$PSScriptRoot\7za.exe"
[string]$7zipArgs = "a -mx=9 -tzip -sdel -p'$secret'"
[string]$7zipSource = "$PSScriptRoot\*.xml" 
[string]$7zipTarget = $instanceTag + '_' + (Get-Date -Format 'yyyyMMddHHmmss') + '.zip'

$7zipCmd = "'$7zip' $7zipArgs '$7zipTarget' '$7zipSource'"

if ((Get-ChildItem -Path $7zipSource).Length -gt 0) {
    Invoke-Expression "&$7zipCmd"
} else {
    Write-Host 'No xml files in current directory. '
}

[string[]]$emailAttachments = (Get-ChildItem -Path "$PSScriptRoot\*.zip.[0-9][0-9][0-9]").FullName
[string]$emailBody = "DBAid collector results for: $SQLServer.$env:USERDNSDOMAIN"

if ($EmailEnable) {
    if ($emailAttachments.Length -gt 0) {
        <######## Send-MailMessage is deprecated, shouldn't be using it. See https://aka.ms/SendMailMessage. MailKit is recommended replacement: https://github.com/jstedfast/MailKit ########>
        Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "DBAid SQL Collector XML" -Body $emailBody -Attachments $emailAttachments -SmtpServer $Smtp
    
        foreach ($item in $emailAttachments) {
            Remove-Item -Path $item -Force
        }
    } else {
        Write-Host 'No zip files in current directory. '
    }
}