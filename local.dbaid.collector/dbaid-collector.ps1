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
    [string[]]$DatamartSqlServer,

    [parameter()]
    [string]$DatamartDatabase
)

Set-Location $PSScriptRoot

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
            $ProcQuery = $ProcQuery + "@update_execution_timestamp=1"
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
                Write-Error "Cannot output XML to: ""$OutputXmlFilePath"" No such path!" -Category ObjectNotFound
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
		        $logInsert = "INSERT INTO [_dbaid].[datamart].[load_log] ([load_type]) VALUES (N'$LoadType')"
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
        & .\comcryptor.ps1 -SqlServer $CollectServer
    }
}
