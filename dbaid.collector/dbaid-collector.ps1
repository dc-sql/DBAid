<#
.SYNOPSIS
    This script connects to one or more SQL Server instances and gathers information for proactive checks.
    
.DESCRIPTION
    This script works for Windows only.

    This script is part of the DBAid toolset.

    This script connects to the specified SQL Server instance(s) and runs stored procedures in the [collector] schema of the [_dbaid] database.
    
    You will need to specify values for either OutputXmlFilePath or DatamartSqlServer and DatamartDatabase, otherwise you won't see any output!

.PARAMETER CollectSqlServer
    This is a string array of SQL Server instances to connect to. 
    
    The entries use standard .NET connection string format. For example:

    [string[]]$SqlServer = @("Data Source=Server1;")
    [string[]]$SqlServer = @("Data Source=Server1\Instance1;")
    [string[]]$SqlServer = @("Data Source=192.168.1.2,1435;")
    [string[]]$SqlServer = @("Data Source=Server1;", "Data Source=Server1\Instance1;", "Data Source=Server1,1435;")

    As these are standard .NET connection strings, you can include additional parameters (for example, Encrypt, MultiSubnetFailover, ConnectionTimeout) separated by semi-colons. For example:
    
    [string[]]$SqlServer = @("Data Source=Server1;MultiSubnetFailover=True;", "Data Source=Server1\Instance1;Encrypt=True;", "Data Source=Server1,1435;Encrypt=True;TrustServerCertificate=True;")


.PARAMETER CollectDatabase
    This is the database containing the stored procedures to run to gather information. Always "_dbaid".
    
.PARAMETER UpdateExecTimestamp
    This switch updates metadata in the CollectDatabase regarding last execution time.
    
.PARAMETER OutputXmlFilePath
    If specified, XML files are generated and saved to this path. If blank, and neither DatamartSqlServer and DatamartDatabase are specified, no output will be generated. XML file names start with the GUID for the server (created as part of [_dbaid] database installation), have the name of the procedure executed, with the current datetime appended in the format yyyymmddHHmm.
    For example: 93D366FF-FAD9-4061-88BD-B3827EBFC978_get_instance_ci_202011031408.xml
    
.PARAMETER ZipXml
    This switch causes output XML files to be copied into a password-protected zip file. Primarily intended to be used when emailing output to a monitoring mailbox. NB - ensure value for SANITISED in [system].[configuration] in [_dbaid] database is set to 1. Password protected is not encrypted! 
    Zip files are named with the GUID for the server (created as part of [_dbaid] database installation) with the current datetime appended in the format yyyymmddHHmm.
    For example: 93D366FF-FAD9-4061-88BD-B3827EBFC978_202011031408.zip

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

.LINK
    SqlServer PowerShell package: https://www.powershellgallery.com/packages/SqlServer/21.1.18229
.LINK
    Send-MailKitMessage PowerShell package: https://www.powershellgallery.com/packages/Send-MailKitMessage/2.0.1

.EXAMPLE
    dbaid-collector.ps1

    If you have configured the required parameters in the script file itself, this is all that needs to be executed.

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1" -OutputXmlFilePath "C:\DBAid\Output"

    This connects to the default SQL Server instance on "Server1" and outputs XML files to "C:\DBAid\Output". 

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1" -OutputXmlFilePath "/var/log/dbaid-collector"

    This connects to the default SQL Server instance on "Server1" and outputs XML files to "/var/log/dbaid-collector". 

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1\Instance1" -OutputXmlFilePath "C:\DBAid\Output" -UpdateExecTimeStamp

    This connects to the named SQL Server instance "Instance1" on "Server1" and outputs XML files to "C:\DBAid\Output". Metadata in the "_dbaid" database regarding last execution time of the collector procedures is updated.

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1,50000" -OutputXmlFilePath "C:\DBAid\Output"

    This connects to the SQL Server instance on "Server1" listening on TCP port 50000 and outputs XML files to "C:\DBAid\Output". 

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1;Encrypt" -OutputXmlFilePath "C:\DBAid\Output" -ZipXml

    This connects to the default SQL Server instance on "Server1" that has TLS connection encryption enabled and outputs XML files to "C:\DBAid\Output". The XML files are added to a password-protected zip file then deleted from disk. 

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1" -OutputXmlFilePath "C:\DBAid\Output" -ZipXml

    This connects to the default SQL Server instance on "Server1" and outputs XML files to "C:\DBAid\Output". The XML files are added to a password-protected zip file then deleted from disk. 

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1" -OutputXmlFilePath "C:\DBAid\Output" -ZipXml -EmailEnable -EmailTo "someone@domain.co.nz" -EmailFrom "Server1@domain.net.nz" -EmailSMTP "smtp.domain.co.nz"

    This connects to the default SQL Server instance on "Server1" and outputs XML files to "C:\DBAid\Output". The XML files are added to a password-protected zip file then deleted from disk. The zip file is then emailed to "someone@domain.co.nz" via "smtp.domain.co.nz" then deleted from disk.

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer "Data Source=Server1" -DatamartSqlServer "DWServer1" -DatamartDatabase "_dbaid_warehouse"

    This connects to the default SQL Server instance on "Server1" and sends data to the "_dbaid_warehouse" database on the default SQL Server instance on "DWServer1". The "_dbaid_warehouse" database uses the same schema as the "_dbaid" database.

.EXAMPLE
    dbaid-collector.ps1 -CollectSqlServer @("Data Source=Server1","Data Source=Server1\Instance1") -OutputXmlFilePath "C:\DBAid\Output"

    This connects to both the default SQL Server instance and named SQL Server instance "Instance1" on "Server1" and outputs XML files to "C:\DBAid\Output".
#>
Param(
    [parameter()]
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

Import-Module Send-MailKitMessage
Import-Module SqlServer

$Timestamp = Get-Date -Format 'yyyyMMddHHmm'

foreach ($CollectServer in $CollectSqlServer) {
  
    <#  Build final connectionstring #>
    [string]$ConnectionString = ''

    <#  If running PowerShell 6 or higher, could use system $IsWindows. Lowest requirement for this script to work, however, is PowerShell 5. Can revisit in the future.  #>
    if ($Env:PSModulePath -like "*\WindowsPowerShell\Modules*") {
        $IsThisWindows = 1
        $Slash = "\"
    }
    else {
        $IsThisWindows = 0
        $Slash = "/"
    }

    <##### Get credentials to connect to SQL Server (Linux only; Windows uses service account of SQL Agent service (if run as SQL Agent job) or AD login if run via Windows Task Scheduler.) #####>
    if ($IsThisWindows -eq 0) {
        <##### Need to store this credential elsewhere, as it is unrelated to Checkmk. Process needs steps to create required folder & set permissions #####>
        $HexPass = Get-Content "/usr/local/bin/dbaid-collector.cred"
        $Credential = New-Object -TypeName PSCredential -ArgumentList "_dbaid_collector", ($HexPass | ConvertTo-SecureString)
    }    
    
    <##### Set connection string according to platform. If Windows, use Integrated Security (i.e. service account for Checkmk Agent service). If Linux, use SQL native login. #####>
    if ($IsThisWindows -eq 1) {
        $ConnectionString = -join ($Instance, ';Initial Catalog=_dbaid;Application Name=DBAid Collector;Integrated Security=SSPI;')
    }
    else {
        $ConnectionString = -join ($Instance, ';Initial Catalog=_dbaid;Application Name=DBAid Collector;User=_dbaid_collector;Password=', $Credential.GetNetworkCredential().Password)
    }
    
    Write-Verbose -Message "Connecting to: $CollectServer"
    $InstanceTag = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query 'EXEC [system].[get_instance_tag]' | Select-Object -ExpandProperty instance_tag
    $ProcedureList = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "EXEC [system].[get_procedure_list] @schema_name = 'collector'"

    # EXPORT DATA #
    foreach ($Procedure in $ProcedureList) {
        $ProcQuery = 'EXEC ' + ($Procedure).procedure

        $ProcSchema = (((($Procedure).procedure).Split('.')).Replace(']', '')).Replace('[', '')[0]
        $ProcName = (((($Procedure).procedure).Split('.')).Replace(']', '')).Replace('[', '')[1]

        if ($UpdateExecTimestamp) {
            $ProcQuery = $ProcQuery + " @update_execution_timestamp = 1"
        }

        Write-Verbose -Message "Executing: $ProcQuery"
        $dt = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $ProcQuery -OutputAs DataTables

        if ($dt) {
            $dt.TableName = $ProcName 
        } else {
            $dt = New-Object System.Data.Datatable($ProcName)
        }

        <#  NB - [owner_sid] value will get garbled due to conversion from varbinary to sql_variant in [collector].[get_database_ci]  #>
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

    if ($ZipXml) {
        $SQLServer = (Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "SELECT @@SERVERNAME")[0]
        [string]$secret = (Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "SELECT [value] FROM [$CollectDatabase].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'")[0]
        # declared above... don't need it here as well [string]$InstanceTag = (Invoke-Sqlcmd -ConnectionString $ConnectionString -Query "EXEC [$CollectDatabase].[system].[get_instance_tag];")[0]
        if ($IsThisWindows -eq 1) {
            [string]$7zip = "$PSScriptRoot" + $Slash + "7za.exe"
        }
        else {
            [string]$7Zip = "7za"
        }
        [string]$7zipArgs = "a -mx=9 -tzip -sdel -p'$secret'"
        [string]$7zipSource = "$OutputXmlFilePath" + $Slash + "$InstanceTag*.xml" 
        [string]$7zipTarget = "$OutputXmlFilePath" + $Slash + $InstanceTag + '_' + (Get-Date -Format 'yyyyMMddHHmmss') + '.zip'

        $7zipCmd = "'$7zip' $7zipArgs '$7zipTarget' '$7zipSource'"

        if ((Get-ChildItem -Path $7zipSource).Length -gt 0) {
            Invoke-Expression "&$7zipCmd"
        } else {
            Write-Host 'No xml files in current directory to add to zip file. '
        }

        if ($EmailEnable) {
            [string[]]$EmailAttachments = (Get-ChildItem -Path "$OutputXmlFilePath\*.zip").FullName
            [string]$EmailBody = "DBAid collector results for: $SQLServer"

            if ($EmailAttachments.Length -gt 0) {
            <#  Send-MailMessage is deprecated. MailKit is recommended replacement. See links above.  #>
            Send-MailKitMessage -SMTPServer $EmailSMTP -Port 25 -From $EmailFrom -RecipientList $EmailTo -Subject "DBAid SQL Collector XML" -HTMLBody $EmailBody -AttachmentList $EmailAttachments
    
            foreach ($item in $EmailAttachments) {
                Remove-Item -Path $item -Force
            }
            } else {
                Write-Host 'No zip files to remove in current directory. '
            }
        }
    }
}
