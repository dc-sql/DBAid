<#
.SYNOPSIS
    DBAid Version 6.4.4
    This script is for use as a Checkmk plugin. It requires minimum SQL PowerShell module v5 and minimum .NET 4.0.
    
.DESCRIPTION

    Copyright (C) 2015 Datacom
    GNU GENERAL PUBLIC LICENSE
    Version 3, 29 June 2007

    This script is part of the DBAid toolset.

    This script connects to the specified SQL Server instance(s) and runs stored procedures in the [check] and [chart] schemas of the [_dbaid] database.

    It is intended that the script connects to SQL Server instance(s) on the machine it is running from, not remote SQL Server instances.

    Copy this file into [C:\Program Files (x86)\check_mk\local]. 
    
    (NB - this is the default plugin folder location)
    
.PARAMETER SqlServer
    This is a string array of SQL Server instances to connect to. It can be passed in as a parameter when running the script manually, but Checkmk just executes the script without passing parameter values, so you will need to edit the script to put in desired values. 

    The entries use standard .NET connection string format. For example:

    [string[]]$SqlServer = @("Data Source=Server1;")
    [string[]]$SqlServer = @("Data Source=Server1\Instance1;")
    [string[]]$SqlServer = @("Data Source=192.168.1.2,1435;")
    [string[]]$SqlServer = @("Data Source=Server1;", "Data Source=Server1\Instance1;", "Data Source=Server1,1435;")

    Or if for some reason you are passing the parameter in when running the script (which you wouldn't be doing under normal circumstances):

    $servers = @("Data Source=Server1;","Data Source=Server1\Instance1;","Data Source=Server1,1435;")
    .\dbaid-checkmk.ps1 -SqlServer $servers
    
    As these are standard .NET connection strings, you can include additional parameters (for example, Encrypt, MultiSubnetFailover, ConnectionTimeout) separated by semi-colons. For example:
    
    [string[]]$SqlServer = @("Data Source=Server1;MultiSubnetFailover=True;", "Data Source=Server1\Instance1;Encrypt=True;", "Data Source=Server1,1435;Encrypt=True;TrustServerCertificate=True;")
    

.LINK
    DBAid source code: https://github.com/dc-sql/DBAid

.LINK 
    Official Checkmk site: https://checkmk.com

.LINK
    Invoke-Sqlcmd command: https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-Sqlcmd?view=sqlserver-ps

.LINK
    .NET ConnectionString keywords: https://docs.microsoft.com/en-us/dotnet/api/system.data.sqlclient.sqlconnection.connectionstring?view=dotnet-plat-ext-5.0

.EXAMPLE
    Windows:    
    %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe dbaid-checkmk.ps1

    Example output:

    0 mssql_MSSQLSERVER - Microsoft SQL Server 2016 (SP3) (KB5003279) - 13.0.6300.2 (X64)       Aug 7 2021 01:20:37 Copyright (c) Microsoft CorporationDeveloper Edition (64-bit) on Windows 10 Enterprise 10.0 <X64> (Build 18363: ) (Hypervisor)
    1 mssql_agentjob_MSSQLSERVER count=2 WARNING - job=[Fail Job 1];state=FAIL;runtime_min=0.00;runtime_check_min=200;\n job=[Fail Job 2];state=FAIL;runtime_min=0.00;runtime_check_min=200;\n 
    0 mssql_alwayson_MSSQLSERVER count=0 NA - Always-On is not available.;\n 
    1 mssql_backup_MSSQLSERVER count=7 WARNING - [master]; recovery_model=SIMPLE; last_full=2020-10-29 13:06:05; last_diff=NEVER; last_tran=NEVER;\n [model]; recovery_model=FULL; last_full=2020-10-29 13:06:06; last_diff=NEVER; last_tran=NEVER;\n [msdb]; recovery_model=SIMPLE; last_full=2020-10-29 13:06:06; last_diff=NEVER; last_tran=NEVER;\n [AdventureWorks2016]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [AdventureWorksDW2016]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [_dbaid]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [TestFG]; recovery_model=FULL; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n 
    0 mssql_database_MSSQLSERVER count=0 NA - 8 online; 0 restoring; 0 recovering;\n 
    1 mssql_integrity_MSSQLSERVER count=6 WARNING - database=[master]; last_checkdb=2020-05-27 10:40:28;\n database=[model]; last_checkdb=2020-05-27 10:40:29;\n database=[msdb]; last_checkdb=2020-05-27 10:40:29;\n database=[AdventureWorks2016]; last_checkdb=2019-08-02 17:13:47;\n database=[AdventureWorksDW2016]; last_checkdb=2019-08-02 17:13:49;\n database=[TestFG]; last_checkdb=NEVER;\n 
    0 mssql_logshipping_MSSQLSERVER count=0 NA - Logshipping is currently not configured.;\n 
    0 mssql_mirroring_MSSQLSERVER count=0 NA - Mirroring is currently not configured.;\n 
    0 mssql_capacity_combined_MSSQLSERVER 'C'=360003.00;549504.00;248727728.00;0;261164114.40 
    0 mssql_capacity_fg_MSSQLSERVER _dbaid_LOG; used=0.79; reserved=8.00; max=26161.00|_dbaid_ROWS_PRIMARY; used=5.25; reserved=8.00; max=26161.00|AdventureWorks2016_LOG; used=0.70; reserved=2.00; max=26155.00|AdventureWorks2016_ROWS_PRIMARY; used=205.44; reserved=207.63; max=26360.63

#>

<#  List of SQL Server instances to connect to. Use .NET connection string so additional options like EncryptConnection and MultiServerFailover can be used.
    Connection authentication (Integrated Security or User & Password) will be appended automatically.
#>
Param(
    [parameter(Mandatory=$false)]
    [string[]]$SqlServer = @("Data Source=localhost;")
)
Set-Location $PSScriptRoot

<#  Loop through the SQL instances one by one.  #>
foreach ($Instance in $SqlServer) {
try {
    <#  Database holding required procedures to run for checks.  #>
    [string]$Database = '_dbaid'
    
    <#  Reset variable to null otherwise catch block returns incorrect value.  #>
    [string]$InstanceName = $null

    <#  Build final connectionstring #>
    [string]$ConnectionString = ''

    <##### Set connection string #####>
    $ConnectionString = -join ($Instance, ';Initial Catalog=', $Database, ';Application Name=Checkmk;Integrated Security=SSPI;')

    <#
        The next bit will get tripped up if you are trying to run this script on one machine but connecting to a SQL instance running on another machine.
        But then as per .DESCRIPTION above, this script is supposed to be executed on the machine that SQL Server is installed on.
        We could test for this, but this in turn would get tripped up by instances running in Docker containers (example scenario being multiple instances on a single host).
          The SERVERPROPERTY('ComputerNamePhysicalNetBIOS') function on a SQL instance in a Docker container returns the name assigned to the Docker container, not the host name.
          The check_mk_agent runs on the host, not within the Docker container, so $Env:HOSTNAME will return the host name, not the Docker container name.
    #>

    <#  Check if this is a clustered SQL instance. #>
    $IsClustered = Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT CAST(SERVERPROPERTY('IsClustered') AS tinyint) AS [IsClustered]"
        
    <#  Get NetBIOS name according to SQL Server. I.e. computer name that SQL instance is running on.  #>
    $NetBIOSName = Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [NetBIOSName]"

    <#  Get computer name according to PowerShell. This may be different than what SQL Server thinks if SQL Server is clustered.  #>
    $ComputerName = $env:computername

    <#  If computer name & NetBIOS name don't match and SQL instance is clustered, this script is running on the passive node for this SQL instance; so don't run the SQL checks, they'll be run on the active node.  #>
    <#  NB - Machine account for each node needs to have its own login in SQL Server and rights to _dbaid database (admin & monitor roles). #>
    if ($ComputerName.ToUpper() -ne $NetBIOSName.NetBIOSName.ToUpper() -and $IsClustered.IsClustered -eq 1) {
        continue
    }

    <#  Get list of procedures to run for checks. All should be in the [checkmk] schema.  #>
    $CheckProcedureList = (Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'check'").proc
    $ChartProcedureList = (Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'chart'").proc
    $InventoryProcedureList = (Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'maintenance' AND [name] LIKE N'check_config%'").proc

    <#  Get SQL Server version information. Pass through function to remove invalid characters and have on one line for Checkmk to handle it.  #>
    $InstanceVersion = (Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT * FROM [dbo].[get_instance_version](0)").string

    <#  Refresh check configuration (i.e. to pick up any new jobs or databases added since last check).  #>
    foreach ($iproc in $InventoryProcedureList) {
        Invoke-SqlCmd -ConnectionString $ConnectionString -Query "EXEC $iproc" -OutputAs DataSet
    }
    
    <#  Get SQL instance name. Used in output as part of Checkmk service name.  #>
    $InstanceName = (Invoke-SqlCmd -ConnectionString $ConnectionString -Query "SELECT ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS [InstanceName]").InstanceName
    
    <#  Output SQL Server instance information in Checkmk format.  #>
    #Write-Host "0 mssql_$($InstanceName) - $($InstanceVersion)"
    Write-Host "$($InstanceVersion)"

    <#  Process each check procedure in the [checkmk] schema.  #>
    foreach ($ckproc in $CheckProcedureList) {
        <#  Pull part of procedure name to use in Checkmk service name.  #>
        $ServiceName = $ckproc.Substring($ckproc.IndexOf('.') + 2).Replace(']','')

        <#  Execute procedure, store results in dataset variable (i.e. PowerShell table equivalent).  #>
        $ckDataSet = Invoke-SqlCmd -ConnectionString $ConnectionString -Query "EXEC $ckproc" -OutputAs DataSet

        <#  Get rowcount of dataset variable. If the top row returned has [state] value of 'NA', then set count=0 (i.e. monitor doesn't apply, nothing wrong detected). If there's more than one row returned, there's probably a fault.  #>
        $Count = $ckDataSet.Tables[0].Rows.Count
        $Count = Switch($ckDataSet.Tables[0].Rows[0].state){'NA'{0} default{$Count}}

        <#  Get status for the monitor as indicated by value in [state] column.  #>
        $Status = Switch($ckDataSet.Tables[0].Rows[0].state){ 'NA'{0} 'OK'{0} 'WARNING'{1} 'CRITICAL'{2} default{3}}

        <#  Initialize variables for storing state & status detail strings.  #>
        [string]$StatusDetails = ""
        [string]$State = ""
        [bool]$IsMultiRow = 0

        if ($ckproc -eq "[check].[backup]") || ($ckproc -eq "[check].[inventory]"){
            $IsMultiRow = 1
        }
        else {
            $IsMultiRow = 0
        }

        <# this loop concatenates row message data into one message. #>
        <# NB - for backups, need to have data on one line otherwise it can't be pulled into DOME (only the first line comes through). #>
        if ($IsMultiRow){
            foreach ($ckrow in $ckDataSet.Tables[0].Rows) {
                $StatusDetails += $ckrow.message + "~"
                $State = $ckrow.state
            }
        }
        else {
            foreach ($ckrow in $ckDataSet.Tables[0].Rows) {
                $StatusDetails += $ckrow.message + ";\n "
                $State = $ckrow.state
            }
        }

        if ($IsMultiRow) && ($StatusDetails.Substring($StatusDetails.Length - 1, 1)) -eq "~") {
            $StatusDetails = $StatusDetails.Substring(1, $StatusDetails.Length - 1)
        }

        <#  Write output for Checkmk agent to consume.  #>
        Write-Host "$Status mssql_$($ServiceName)_$($InstanceName) count=$Count $State - $StatusDetails"
    }

    <#  Process each chart procedure in the [checkmk] schema.  #>
    foreach ($ctproc in $ChartProcedureList) {
        <#  Variables to manage pnp chart data. Initialize for each row of data being processed (i.e. per procedure call).  #>
        [string]$pnpData = ""
        [int]$row = 0
        [string]$State = ""
        [int]$Status = 0
        [string]$StatusDetails = ""
    
        <#  Pull part of procedure name to use in Checkmk service name.  #>
        $ServiceName = $ctproc.Substring($ctproc.IndexOf('.') + 2).Replace(']','')

        <#  Execute procedure, store results in dataset variable (i.e. PowerShell table equivalent).  #>
        $ctDataSet = Invoke-SqlCmd -ConnectionString $ConnectionString -Query "EXEC $ctproc" -As DataSet

        foreach ($ctrow in $ctDataset.Tables[0].Rows) {
            <#  Variables to manage pnp chart data. Initialize for each row of data being processed (i.e. each database or performance monitor counter).  #>
            [bool]$WarnExist = 0
            [bool]$CritExist = 0
            [decimal]$val = 0.0
            [decimal]$warn = 0.0
            [decimal]$crit = 0.0

            <#  Check for current value, warning threshold, critical threshold, pnp chart data.  #>
            <#  chart.capacity has different columns returned compared to anything else, so has its own code to handle data.  #>
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

            <#  If there is no chart data, skip the rest and move to next row in the data set.  #>
            if ($pnpData -eq "" -and $val -eq -1.0) {
                continue
            }

            <#  Check to see if warning and critical thresholds are defined, then check current value $val against threshold values for warning $warn and critical $crit.  #>
            if ($CritExist -and $WarnExist) {
                if ($crit -ge $warn) {
                    if ($val -ge $crit) {
`                            <#  Split the pnp data at the '=' character to form a new array, take the first element of the new array [0] which amounts to the object exceeding a threshold (e.g. dbname_ROWS_used) and remove the single quote characters.  #>
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

            <#  Concatenate all the pnp data into one text string for Checkmk to consume. Use pipe separator for subsequent rows being concatenated.  #>
            if ($row -eq 0) {
                $StatusDetails += $ctrow.pnp
            }
            else {
                $StatusDetails += "|" + $ctrow.pnp
            }
            $row++
        }

        if ($State = "") {
            $State = "OK"
        }

        <#  Write output for Checkmk agent to consume.  #>
        Write-Host "$Status mssql_$($ServiceName)_$($InstanceName) $StatusDetails $State"
    }
}
catch {
    <#  Work out the instance name based on name provided as we may not have been able to connect.  #>
    if ($null -eq $InstanceName) {
        $InstanceName = $Instance.ToUpper().Split('\')[1]  # element [0] is machine name, element [1] is instance name.  NB - MAY GET ODDITY IF "SERVER\INSTANCE,1234" IS PASSED OR IF NO INSTANCE SPECIFIED, JUST TCP PORT
        if ($null -eq $InstanceName) {
            $InstanceName = 'MSSQLSERVER'
        }
        <#  Strip off any additional parameters passed in with server\instance name (e.g. -EncryptConnection) if they were specified. They're not part of the instance name.  #>
        $InstanceName = $InstanceName.Split(' ')[0]  # element [0] is instance name, elements [1..N] we don't care about
    }

    <#  Write output for Checkmk agent to consume.  #>
    Write-Host "2 mssql_$($InstanceName) - WARNING - Unable to run one or more SQL Server checks. Check the following: Name is correct in dbaid-checkmk.ps1, SQL Server is running, permissions are granted to Checkmk service account in SQL Server."

    <#  Extra debug information used when writing/troubleshooting script. 
    Write-Host $_
    Write-Host $_.ScriptStackTrace
    #>
}
finally {
    <#  Clean up the variables rather than waiting for .NET garbage collector.  #>
    If (Test-Path variable:local:ConnectionString) { Remove-Variable ConnectionString }
    If (Test-Path variable:local:Database) { Remove-Variable Database }
    If (Test-Path variable:local:ConnectionString) { Remove-Variable ConnectionString }
    If (Test-Path variable:local:SQLQuery) { Remove-Variable SQLQuery }
    If (Test-Path variable:local:CheckProcedureList) { Remove-Variable CheckProcedureList }
    If (Test-Path variable:local:ChartProcedureList) { Remove-Variable ChartProcedureList }
    If (Test-Path variable:local:InventoryProcedureList) { Remove-Variable InventoryProcedureList }
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