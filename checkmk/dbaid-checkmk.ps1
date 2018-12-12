Param(
    [parameter(Mandatory=$false)]
    [string[]]$SqlServer = @("SETTSPSQLD01")
)
CD $PSScriptRoot
$OutputPath = $PSScriptRoot

foreach ($Instance in $SqlServer) {
    $InstanceTag = (Invoke-Sqlcmd -ServerInstance $Instance -Database '_dbaid' -Query 'EXEC [system].[get_instance_tag]')[0]
    $ProcedureList = (Invoke-Sqlcmd -ServerInstance $Instance -Database '_dbaid' -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] NOT LIKE N'inventory%'").proc

    Write-Host "#### $Instance" -BackgroundColor Red
    foreach ($proc in $ProcedureList) {
        $ProcedureTag = $proc.Substring($proc.IndexOf('_') + 1).Replace(']','')

        Write-Host $ProcedureTag -BackgroundColor Magenta
        Invoke-Sqlcmd -ServerInstance $Instance -Database '_dbaid' -Query "EXEC $proc" | Format-Table -AutoSize
    }
}