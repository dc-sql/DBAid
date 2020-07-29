<##### List of SQL Server instances to check. E.g. @("server1","server1\instance1") #####>
<##### If an instance is using TLS, add -EncryptConnection. E.g. @("server1 -EncryptConnection", "server1\instance1 -EncryptConnection", "server1\instance2") #####>
Param(
    [parameter(Mandatory=$false)]
    [string[]]$SqlServer = @("ServerName1")
)
Set-Location $PSScriptRoot


foreach ($Instance in $SqlServer) {
try {
    <##### Database holding required procedures to run for checks. #####>
    [string]$Database = '_dbaid'
    
    <##### Reset variable to null otherwise catch block returns incorrect value #####>
    $InstanceName = $null

    <##### When $Instance is expanded, it will include -EncryptConnection (if specified) which will be interpreted as a switch to Invoke-Sqlcmd #####>
    $ConnectionString = "Invoke-SqlCmd -ServerInstance $($Instance) -Database $($Database) -Query "

    <##### Check if this is a clustered SQL instance. #####>
    $SQLQuery = $ConnectionString + "`"SELECT CAST(SERVERPROPERTY('IsClustered') AS bit) AS [IsClustered]`""
    $IsClustered = Invoke-Expression $SQLQuery

    <##### Get NetBIOS name according to SQL Server. I.e. computer name that SQL instance is running on #####>
    $SQLQuery = $ConnectionString + "`"SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [NetBIOSName]`""
    $NetBIOSName = Invoke-Expression $SQLQuery

    <##### Get computer name according to PowerShell. This may be different than what SQL Server thinks if SQL Server is clustered #####>
    $ComputerName = $env:computername

    <##### if computer name & NetBIOS name don't match and SQL instance is clustered, this script is running on the passive node for this SQL instance; so don't run the SQL checks, they'll be run on the active node #####>
    if ($ComputerName.ToUpper() -ne $NetBIOSName.NetBIOSName.ToUpper() -and $IsClustered.IsClustered -eq 1) {
        continue
    }

    <##### Get list of procedures to run for checks. All should be in the [check] or [checkmk] schema (depending if DBAid or DBAid2)  #####>
    # DBAid2
    #$SQLQuery = $ConnectionString + "`"SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'check%'`""
    #$CheckProcedureList = (Invoke-Expression $SQLQuery).proc
    #$SQLQuery = $ConnectionString + "`"SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'chart%'`""
    #$ChartProcedureList = (Invoke-Expression $SQLQuery).proc
    #$SQLQuery = $ConnectionString + "`"SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'inventory%'`""
    #$InventoryProcedureList = (Invoke-Expression $SQLQuery).proc
    # DBAid
    $SQLQuery = $ConnectionString + "`"SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'check'`""
    $CheckProcedureList = (Invoke-Expression $SQLQuery).proc

    $SQLQuery = $ConnectionString + "`"SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'chart'`""
    $ChartProcedureList = (Invoke-Expression $SQLQuery).proc

    <##### DAC version for DBAid DAC package (not sure what this is to be used for) #####>
    #$SQLQuery = $ConnectionString + "`"SELECT [type_version] FROM msdb.dbo.sysdac_instances WHERE [instance_name] = N'_dbaid'`""
    #$DBAidVersion = (Invoke-Expression $SQLQuery)

    <##### Get SQL instance name. Used in output as part of CheckMK service name #####>
    $SQLQuery = $ConnectionString + "`"SELECT ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS [InstanceName]`""
    $InstanceName = (Invoke-Expression $SQLQuery)

    <##### Get SQL Server version information. Pass through function to remove invalid characters and have on one line for CheckMK to handle it. Function name different between DBAid and DBAid2. #####>
    # DBAid2
    #$SQLQuery = $ConnectionString + "`"SELECT [clean_string] AS [InstanceVersion] FROM [system].[get_clean_string](@@VERSION)`""
    #$InstanceVersion = (Invoke-Expression $SQLQuery)
    # DBAid
    $SQLQuery = $ConnectionString + "`"SELECT [string] AS [InstanceVersion] FROM [dbo].[cleanstring](@@VERSION)`""
    $InstanceVersion = (Invoke-Expression $SQLQuery)

    <##### Refresh check configuration (e.g. to pick up any new jobs or databases added since last check) #####>
    # DBAid2
    #foreach ($iproc in $InventoryProcedureList) {
    #    $SQLQuery = $sqlcmd + "`"EXEC $iproc`""
    #    Invoke-Expression $SQLQuery
    #}
    # DBAid
    $SQLQuery = $ConnectionString + "`"EXEC [maintenance].[check_config]`""
    Invoke-Expression $SQLQuery

    <##### Output SQL Server instance information in CheckMK format #####>
    Write-Host "0 mssql_$($InstanceName.InstanceName) - $($InstanceVersion.InstanceVersion)"
    
    <##### Process each check procedure in the [check] or [checkmk] schema (depending on whether DBAid or DBAid2) #####>
    foreach ($ckproc in $CheckProcedureList) {
        <##### Pull part of procedure name to use in CheckMK service name. Different for DBAid and DBAid2 #####>
        # DBAid2
        #$ServiceName = $ckproc.Substring($ckproc.IndexOf('_') + 1).Replace(']','')
        # DBAid
        $ServiceName = $ckproc.Substring($ckproc.IndexOf('.') + 2).Replace(']','')

        <##### Execute procedure, store results in dataset variable (i.e. PowerShell table equivalent) #####>
        $SQLQuery = $ConnectionString + "`"EXEC $ckproc`" -As DataSet"
        $ckDataSet = Invoke-Expression $SQLQuery
        
        <##### Get rowcount of dataset variable. If the top row returned has [state] value of 'NA', then set count=0 (basically, nothing wrong detected). If there's more than one row returned, there's probably a fault. #####>
        $Count = $ckDataSet.Tables[0].Rows.Count
        $Count = Switch($ckDataSet.Tables[0].Rows[0].state){'NA'{0} default{$Count}}

        <##### Get status for the monitor as indicated by value in [state] column. #####>
        $Status = Switch($ckDataSet.Tables[0].Rows[0].state){ 'NA'{0} 'OK'{0} 'WARNING'{1} 'CRITICAL'{2} default{3}}

        <##### Initialize variables for storing state & status detail strings #####>
        [string]$StatusDetails = ""
        [string]$State = ""

        foreach ($ckrow in $ckDataSet.Tables[0].Rows) {
            $StatusDetails += $ckrow.message + ";\n "
            $State = $ckrow.state
        }

        <##### write output for CheckMK agent to consume #####>
        Write-Host "$Status mssql_$($ServiceName)_$($InstanceName.InstanceName) count=$Count $State - $StatusDetails"
        
    }

    <##### Process each chart procedure in the [check] or [checkmk] schema (depending on whether DBAid or DBAid2) #####>
    foreach ($ctproc in $ChartProcedureList) {
        <##### variables to manage pnp chart data. Initialize for each row of data being processed (i.e. per procedure call). #####>
        [string]$pnpData = ""
        [int]$row = 0
        $State = ""
        $Status = 0
        $StatusDetails = ""
    
        <##### Pull part of procedure name to use in CheckMK service name. Different for DBAid and DBAid2 #####>
        # DBAid2
        #$ServiceName = $ctproc.Substring($ctproc.IndexOf('_') + 1).Replace(']','')
        # DBAid
        $ServiceName = $ctproc.Substring($ctproc.IndexOf('.') + 2).Replace(']','')

        <##### Execute procedure, store results in dataset variable (i.e. PowerShell table equivalent) #####>
        $SQLQuery = $ConnectionString + "`"EXEC $ctproc`" -As DataSet"
        $ctDataSet = Invoke-Expression $SQLQuery

        foreach ($ctrow in $ctDataset.Tables[0].Rows) {
            <##### variables to manage pnp chart data. Initialize for each row of data being processed (i.e. each database or performance monitor counter). #####>
            [bool]$WarnExist = 0
            [bool]$CritExist = 0
            [decimal]$val = 0.0
            [decimal]$warn = 0.0
            [decimal]$crit = 0.0

            <##### Check for current value, warning threshold, critical threshold, pnp chart data #####>
            if (([DBNull]::Value).Equals($ctrow.val)) { 
                $val = -1.0
            }
            else {
                $val = $ctrow.val
            }
            if (([DBNull]::Value).Equals($ctrow.warn)) { 
                $WarnExist = 0
                $warn = 0.0
            }
            else {
                $WarnExist = 1
                $warn = $ctrow.warn
            }
            if (([DBNull]::Value).Equals($ctrow.crit)) { 
                $CritExist = 0
                $crit = 0.0
            }
            else {
                $CritExist = 1
                $crit = $ctrow.crit
            }
            if (([DBNull]::Value).Equals($ctrow.pnp)) { 
                $pnpData = ""
            }
            else {
                $pnpData = $ctrow.pnp
            }

            <##### if there is no chart data, skip the rest and move to next row in the data set #####>
            if ($pnpData -eq "" -and $val -eq -1.0) {
                continue
            }

            <##### check to see if warning and critical thresholds are defined, then check current value $val against threshold values for warning $warn and critical $crit #####>
            if ($CritExist -and $WarnExist) {
                if ($crit -ge $warn) {
                    if ($val -ge $crit) {
                        <##### split the pnp data at the '=' character to form a new array, take the first element of the new array [0] which amounts to the object exceeding a threshold (e.g. dbname_ROWS_used) and remove the single quote characters #####>
                        $State += "CRITICAL - " + ($ctrow.pnp).Split('=')[0].Replace("'", "") + "; "
                        $Status = 2
                    }
                    elseif ($val -ge $warn -and $Status -lt 2) {
                        $State += "WARNING - " + ($ctrow.pnp).Split('=')[0].Replace("'", "") + "; "
                        $Status = 1
                    }
                }
            }
            elseif ($crit -lt $warn) {
                if ($val -le $crit) {
                    $State += "CRITICAL - " + ($ctrow.pnp).Split('=')[0].Replace("'", "") + "; "
                    $Status = 2
                }
                elseif ($val -le $warn -and $Status -lt 2) {
                    $State += "WARNING - " + ($ctrow.pnp).Split('=')[0].Replace("'", "") + "; "
                    $Status = 1
                }
            }

            <##### concatenate all the pnp data into one text string for CheckMK to consume. Use pipe separator for subsequent rows being concatenated #####>
            if ($row -eq 0) {
                $StatusDetails += $ctrow.pnp
            }
            else {
                $StatusDetails += "|" + $ctrow.pnp
            }

            $row++
        }

        <##### write output for CheckMK agent to consume #####>
        Write-Host "$Status mssql_$($ServiceName)_$($InstanceName.InstanceName) $StatusDetails $State"
    }
}
catch {
    <##### work out the instance name based on name provided as we may not have been able to connect #####>
    if ($null -eq $InstanceName) {
        $InstanceName = $Instance.ToUpper().Split('\')[1]  # element [0] is machine name, element [1] is instance name
        if ($null -eq $InstanceName) {
            $InstanceName = 'MSSQLSERVER'
        }
        <##### Strip off -EncryptConnection if it was specified. It's not part of the instance name #####>
        $InstanceName = $InstanceName.Split(' ')[0]  # element [0] is instance name, elements [1..N] we don't care about
    }

    <##### write output for CheckMK agent to consume #####>
    Write-Host "2 mssql_$($InstanceName) - CRITICAL - Unable to run SQL Server checks. Check the following: Name is correct in dbaid-checkmk.ps1, SQL Server is running, permissions are granted to CheckMK service account in SQL Server."

    <# extra debug information used when writing/troubleshooting script.
    Write-Host $_
    Write-Host $_.ScriptStackTrace
    #>
}
finally {
    <##### Clean up the variables rather than waiting for .NET garbage collector #####>
    If (Test-Path variable:local:Database) { Remove-Variable Database }
    If (Test-Path variable:local:UseTLS) { Remove-Variable UseTLS }
    If (Test-Path variable:local:ConnectionString) { Remove-Variable ConnectionString }
    If (Test-Path variable:local:SQLQuery) { Remove-Variable SQLQuery }
    If (Test-Path variable:local:CheckProcedureList) { Remove-Variable CheckProcedureList }
    If (Test-Path variable:local:ChartProcedureList) { Remove-Variable ChartProcedureList }
    If (Test-Path variable:local:InventoryProcedureList) { Remove-Variable InventoryProcedureList }
    If (Test-Path variable:local:DBAidVersion) { Remove-Variable DBAidVersion }
    If (Test-Path variable:local:IsClustered) { Remove-Variable IsClustered }
    If (Test-Path variable:local:NetBIOSName) { Remove-Variable NetBIOSName }
    If (Test-Path variable:local:ComputerName) { Remove-Variable ComputerName }
    If (Test-Path variable:local:InstanceName) { Remove-Variable InstanceName }
    If (Test-Path variable:local:InstanceVersion) { Remove-Variable InstanceVersion }
    If (Test-Path variable:local:ServiceName) { Remove-Variable ServiceName }
    If (Test-Path variable:local:Count) { Remove-Variable Count }
    If (Test-Path variable:local:Status) { Remove-Variable Status }
    If (Test-Path variable:local:StatusDetails) { Remove-Variable StatusDetails }
    If (Test-Path variable:local:State) { Remove-Variable State }
    If (Test-Path variable:local:ErrorString) { Remove-Variable ErrorString }
    If (Test-Path variable:local:ckrow) { Remove-Variable ckrow }
    If (Test-Path variable:local:ctrow) { Remove-Variable ctrow }
    If (Test-Path variable:local:ckDataSet) { Remove-Variable ckDataSet }
    If (Test-Path variable:local:ctDataSet) { Remove-Variable ctDataSet }
    If (Test-Path variable:local:val) { Remove-Variable val }
    If (Test-Path variable:local:warn) { Remove-Variable warn }
    If (Test-Path variable:local:crit) { Remove-Variable crit }
    If (Test-Path variable:local:pnpData) { Remove-Variable pnpData }
    If (Test-Path variable:local:row) { Remove-Variable row }
    If (Test-Path variable:local:WarnExist) { Remove-Variable WarnExist }
    If (Test-Path variable:local:CritExist) { Remove-Variable CritExist }
}
}