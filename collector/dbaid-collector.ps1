Param(
    [parameter(Mandatory=$false)]
    [string[]]$SqlServer = 'SETTSPSQLD01',

    [parameter(Mandatory=$false)]
    [bool]$UpdateExecTimestamp = 0
)
CD $PSScriptRoot
$OutputPath = $PSScriptRoot

foreach ($Instance in $SqlServer) {
    $InstanceTag = (Invoke-Sqlcmd -ServerInstance $Instance -Database '_dbaid' -Query 'EXEC [system].[get_instance_tag]')[0]
    $ProcedureList = (Invoke-Sqlcmd -ServerInstance $Instance -Database '_dbaid' -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'collector'").proc

    # EXPOR DATA #
    foreach ($proc in $ProcedureList) {
        $ProcedureTag = $proc.Substring($proc.IndexOf('_') + 1).Replace(']','')
        $OutputFile = Join-Path $OutputPath "$InstanceTag`_$ProcedureTag`_$(Get-Date -Format 'yyyyMMddHHmm').xml"

        $dt = Invoke-Sqlcmd -ServerInstance $Instance -Database '_dbaid' -Query "EXEC $proc @update_execution_timestamp = $UpdateExecTimestamp" -OutputAs DataTables
    
        if ($dt) {
            $dt.TableName = $ProcedureTag
        } else {
            $dt = New-Object System.Data.Datatable($ProcedureTag)
        }
  
        $dt.WriteXml($OutputFile, "System.Data.XmlWriteMode"::WriteShema)
    }

    [string]$secret = (Invoke-Sqlcmd -ServerInstance $Instance -Query "SELECT [value] FROM [_dbaid].[system].[configuration] WHERE [key] = N'COLLECTOR_SECRET'")[0]
    [string]$7zip = Join-Path $OutputPath "7za.exe"
    [string]$7zipArgs = "a -mx=9 -tzip -sdel -p'$secret'"
    [string]$7zipSource = Join-Path $OutputPath "$InstanceTag*.xml" 
    [string]$7zipTarget = $instanceTag + '_' + (Get-Date -Format 'yyyyMMddHHmmss') + '.zip'

    $7zipCmd = "'$7zip' $7zipArgs '$7zipTarget' '$7zipSource'"

    if ((Get-ChildItem -Path $7zipSource).Length -gt 0) {
        Invoke-Expression "&$7zipCmd"
    } else {
        Write-Host 'No xml files in current directory. '
    }
}
