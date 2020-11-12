<#
.SYNOPSIS
    This script connects to one or more SQL Server instances and gathers information for proactive checks.
    
.DESCRIPTION
    This script is part of the DBAid toolset.

    This script connects to the specified SQL Server instance(s) and runs stored procedures in the [collector] schema of the [_dbaid] database.
    
    You will need to specify values for either OutputXmlFilePath or DatamartSqlServer and DatamartDatabase, otherwise you won't see any output!

.PARAMETER CollectSqlServer
    This is a string array of SQL Server instances to connect to. 
    
    The entries can use servername or IP address. 
    You can specify a named instance by appending \InstanceName. 
    You can connect to a specific TCP port number by appending ,PortNumber. 
    You can use a combination of the above. As long as it represents a valid server name such as you would use in SQL Server Management Studio or a .NET connection string.
    
    For example:

    [string[]]$CollectSqlServer = @("Server1")
    [string[]]$CollectSqlServer = @("Server1\Instance1")
    [string[]]$CollectSqlServer = @("192.168.1.2,1435")
    [string[]]$CollectSqlServer = @("Server1", "Server1\Instance1", "Server1,1435")

    Or if for some reason you are passing the parameter in when running the script (which you wouldn't be doing under normal circumstances):

    $servers = @("Server1","Server1\Instance1","Server1,1435")
    .\dbaid-checkmk.ps1 -CollectSqlServer $servers
    
    Additional Invoke-Sqlcmd connection string parameters can be specified with the server names. For example, if TLS is used by one of the instances, you can provide the EncryptConnection parameter as follows:
    
    [string[]]$SqlServer = @("Server1", "Server1\Instance1 -EncryptConnection", "Server1,1435")
    
    See Invoke-Sqlcmd documentation for details on parameters (under Related Links).

.PARAMETER CollectDatabase
    This is the database containing the stored procedures to run to gather information. Always "_dbaid".
    
.PARAMETER UpdateExecTimestamp
    This switch updates metadata in the CollectDatabase regarding last execution time.
    
.PARAMETER OutputXmlFilePath
    If specified, XML files are generated and saved to this path. If blank, and neither DatamartSqlServer and DatamartDatabase are specified, no output will be generated.
    
.PARAMETER ZipXml
    This switch causes output XML files to be copied into a password-protected zip file. Primarily intended to be used when emailing output to a monitoring mailbox. NB - ensure value for SANITISED in [system].[configuration] in [_dbaid] database is set to 1. Password protected is not encrypted!

.PARAMETER EmailEnable
    This switch controls whether email with zipped XML files is sent or not.
    
.PARAMETER EmailTo
    This is the recipient of the zipped XML files. Expected to be a shared mailbox/repository.
    
.PARAMETER EmailFrom
    This is where the zipped XML files have come from. Often has the server name as the name. This will depend if you're emailing externally or not. Pick something that makes sense and so you can track it back to the origin if there are issues.
    
.PARAMETER EmailSMTP
    This is the mail (SMTP) server to send email through.

.PARAMETER DatamartSqlServer
    This is the SQL instance to save collector data from [multiple] servers to. Requires a copy of the [_dbaid] database. If blank, is ignored.
    
.PARAMETER DatamartDatabase
    This is the database to save collector data from multiple servers to. Is a copy of the [_dbaid] database schema but can be a different name. Default value is [_dbaid]. Requires DatamartSqlServer parameter to be effective.

.LINK
    DBAid source code: https://github.com/dc-sql/DBAid

.LINK 
    Official CheckMK site: https://checkmk.com

.LINK
    Invoke-Sqlcmd module: https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-Sqlcmd?view=sqlserver-ps

.EXAMPLE
    dbaid-collector.ps1

#>
Param(
    [parameter(Mandatory)]
    [string[]]$CollectSqlServer,

    [parameter()]
    [string]$CollectDatabase = '_dbaid',

    [parameter()]
    [Switch]$UpdateExecTimestamp,

    [parameter()]
    [System.String]$OutputXmlFilePath,

    [parameter()]
    [Switch]$ZipXml,

    [parameter()]
    [Switch]$EmailEnable,

    [parameter()]
    [string]$EmailTo = 'someone@domain.co.nz',

    [parameter()]
    [string]$EmailFrom = 'server@domain.net.nz',

    [parameter()]
    [string]$EmailSMTP = 'smtp.domain.net.nz',

    [parameter()]
    [string[]]$DatamartSqlServer,

    [parameter()]
    [string]$DatamartDatabase = '_dbaid'
)

Set-Location $PSScriptRoot
<##### Requires Send-MailKitMessage PowerShell module: https://www.powershellgallery.com/packages/Send-MailKitMessage/2.0.1 #####>
Import-Module Send-MailKitMessage

$Timestamp = Get-Date -Format 'yyyyMMddHHmm'

foreach ($CollectServer in $CollectSqlServer) {
    Write-Verbose -Message "Connecting to: $CollectServer"
    $InstanceTag = Invoke-Sqlcmd -ServerInstance $CollectServer -Database $CollectDatabase -Query 'EXEC [system].[get_instance_tag]' | Select-Object -ExpandProperty instance_tag
    $ProcedureList = Invoke-Sqlcmd -ServerInstance $CollectServer -Database $CollectDatabase -Query "EXEC [system].[get_procedure_list] @schema_name = 'collector'"

    # EXPORT DATA #
    foreach ($Procedure in $ProcedureList) {
        $ProcQuery = 'EXEC ' + ($Procedure).procedure

        $ProcSchema = (((($Procedure).procedure).Split('.')).Replace(']', '')).Replace('[', '')[0]
        $ProcName = (((($Procedure).procedure).Split('.')).Replace(']', '')).Replace('[', '')[1]

        if ($UpdateExecTimestamp) {
            $ProcQuery = $ProcQuery + " @update_execution_timestamp = 1"
        }

        Write-Verbose -Message "Executing: $ProcQuery"
        $dt = Invoke-Sqlcmd -ServerInstance $CollectServer -Database $CollectDatabase -Query $ProcQuery -OutputAs DataTables

        if ($dt) {
            $dt.TableName = $ProcName 
        } else {
            $dt = New-Object System.Data.Datatable($ProcName)
        }

        <####### NB - [owner_sid] value will get garbled due to conversion from varbinary to sql_variant in [collector].[get_database_ci]  #######>
        if ($OutputXmlFilePath) {
            Write-Verbose -Message "Outputting XML to: $OutputXmlFilePath"
            If (Test-Path $OutputXmlFilePath) {
                $FileName = $InstanceTag + '_' + $ProcName + '_' + $Timestamp + '.xml'
                $OutputFile = Join-Path $OutputXmlFilePath $FileName
                $dt.WriteXml($OutputFile, "System.Data.XmlWriteMode"::WriteSchema)
            } else {
                Write-Error "Cannot output XML to: ""$OutputXmlFilePath"" No such path!" -Category ObjectNotFound  #-ForegroundColor Red
            }
        }

        foreach ($DatamartServer in $DatamartSqlServer) {
            $DestTable = '[datamart].[' + $ProcName + ']'
            $LoadType = $InstanceTag + '_' + $ProcName

            try { # try bulk copy data into destination table
                $cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$DatamartServer;Integrated Security=SSPI;Initial Catalog=$DatamartDatabase");
                $bc = New-Object System.Data.SqlClient.SqlBulkCopy($cn)
                $bc.BatchSize = 10000
                $bc.BulkCopyTimeout = 1000
                $bc.DestinationTableName = $DestTable
                $cn.Open()
                $bc.WriteToServer($dt)
		        $logInsert = "INSERT INTO [$DatamartDatabase].[datamart].[load_log] ([load_type]) VALUES (N'$LoadType')"
		        (New-Object System.Data.SqlClient.SqlCommand($logInsert, $cn)).ExecuteNonQuery() | Out-Null
        
            } catch {
                $_.Exception | Write-Output
            } finally {
                $bc.Close()
                $cn.Close()
            }
        }
    }

<# Offloaded to comcryptor.ps1. Not sure whether to bundle all in one script or not. Would be tidier in some respects
    if ($ZipXml) {
        [string]$Secret = Invoke-Sqlcmd -ServerInstance $CollectServer -Database $CollectDatabase -Query "SELECT [value] FROM [_dbaid].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'" | Select-Object -ExpandProperty value
        [string]$7zip = "7za.exe"
        [string]$7zipArgs = "a -mx=9 -tzip -sdel -p'$Secret'"
        [string]$7zipSource = Join-Path $OutputXmlFilePath "$InstanceTag*.xml" 
        [string]$7zipTarget = $InstanceTag + '_' + $Timestamp + '.zip'

        $7zipCmd = "'$7zip' $7zipArgs '$7zipTarget' '$7zipSource'"

        if ((Get-ChildItem -Path $7zipSource).Length -gt 0) {
            Write-Verbose -Message "Zipping XML file into: $7zipTarget"
            Invoke-Expression "&$7zipCmd"
        } else {
            Write-Error "No xml files found in output directory: $OutputXmlFilePath"
        }
    }
#>

    if ($ZipXml) {
        $SQLServer = (Invoke-Sqlcmd -ServerInstance $CollectServer -Query "SELECT @@SERVERNAME")[0]
        [string]$secret = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "SELECT [value] FROM [$CollectDatabase].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'")[0]
        [string]$instanceTag = (Invoke-Sqlcmd -ServerInstance $SQLServer -Query "EXEC [$CollectDatabase].[system].[get_instance_tag];")[0]
        [string]$7zip = "$PSScriptRoot\7za.exe"
        [string]$7zipArgs = "a -mx=9 -tzip -sdel -p'$secret'"
        [string]$7zipSource = "$OutputXmlFilePath\$instanceTag*.xml" 
        [string]$7zipTarget = "$OutputXmlFilePath\" + $instanceTag + '_' + (Get-Date -Format 'yyyyMMddHHmmss') + '.zip'

        $7zipCmd = "'$7zip' $7zipArgs '$7zipTarget' '$7zipSource'"

        if ((Get-ChildItem -Path $7zipSource).Length -gt 0) {
            Invoke-Expression "&$7zipCmd"
        } else {
            Write-Host 'No xml files in current directory. '
        }

        if ($EmailEnable) {
            [string[]]$EmailAttachments = (Get-ChildItem -Path "$OutputXmlFilePath\*.zip").FullName
            [string]$EmailBody = "DBAid collector results for: $SQLServer.$env:USERDNSDOMAIN"

            if ($EmailAttachments.Length -gt 0) {
            <######## Send-MailMessage is deprecated, shouldn't be using it. See https://aka.ms/SendMailMessage. MailKit is recommended replacement: https://github.com/jstedfast/MailKit ########>
            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "DBAid SQL Collector XML" -Body $EmailBody -Attachments $EmailAttachments -SmtpServer $EmailSMTP
    
            foreach ($item in $EmailAttachments) {
                Remove-Item -Path $item -Force
            }
            } else {
             Write-Host 'No zip files in current directory. '
            }
        }
    }
}
