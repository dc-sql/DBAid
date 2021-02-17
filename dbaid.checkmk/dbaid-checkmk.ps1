<#
.SYNOPSIS
    This script is for use as a CheckMK plugin.
    
.DESCRIPTION
    This script is part of the DBAid toolset.

    This script connects to the specified SQL Server instance(s) and runs stored procedures in the [checkmk] schema of the [_dbaid] database.

    It is intended that the script connects to SQL Server instances on the machine it is running from, not remote SQL Server instances.

    For Windows: Copy this file into [C:\Program Files (x86)\check_mk\local]. 
    For Linux  : Copy this file into [/usr/share/check-mk-agent/plugins]. In addition, a shell script is required as CheckMK on Linux cannot directly execute PowerShell scripts. See Related Links (DBAid source code).
    
    (NB - these are the default plugin folder locations)
    
    This has been tested against SQL instances in Docker containers on a Linux host. 
    Wrinkle: all instances come back as "MSSQLSERVER", as opposed to named instances (because they are not named instances; using Docker is a workaround to have multiple instances on a Linux host).

    Credentials for Linux:

    When configuring the plugin for use in Linux, you will need to create a SQL native login [_dbaid_checkmk] in each instance, with the same password. You will then need to run PowerShell to create a credential for the login and save the encrypted password to a file:
    
    $Credential = Get-Credential
    $Credential.Password | ConvertFrom-SecureString | Out-File /usr/share/check-mk-agent/plugins/dbaid-checkmk.cred

.PARAMETER SqlServer
    This is a string array of SQL Server instances to connect to. It can be passed in as a parameter when running the script manually, but CheckMK just executes the script without passing parameter values, so you will need to edit the script to put in desired values. 

    The entries can use servername or IP address. 
    You can specify a named instance by appending \InstanceName. 
    You can connect to a specific TCP port number by appending ,PortNumber. 
    You can use a combination of the above. As long as it represents a valid server name such as you would use in SQL Server Management Studio or a .NET connection string.
    
    For example:

    [string[]]$SqlServer = @("Server1")
    [string[]]$SqlServer = @("Server1\Instance1")
    [string[]]$SqlServer = @("192.168.1.2,1435")
    [string[]]$SqlServer = @("Server1", "Server1\Instance1", "Server1,1435")

    Or if for some reason you are passing the parameter in when running the script (which you wouldn't be doing under normal circumstances):

    $servers = @("Server1","Server1\Instance1","Server1,1435")
    .\dbaid-checkmk.ps1 -SqlServer $servers
    
    NB - Connecting to servers configured to [only] accept TLS encrypted connections is not currently supported.

.LINK
    DBAid source code: https://github.com/dc-sql/DBAid

.LINK 
    Official CheckMK site: https://checkmk.com

.LINK
    Invoke-Sqlcmd module: https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-Sqlcmd?view=sqlserver-ps

.LINK
    Get-Credential command: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/get-credential?view=powershell-7.1

.EXAMPLE
    Windows:    
    %SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe dbaid-checkmk.ps1

    Example output (Windows):

    0 mssql_MSSQLSERVER - Microsoft SQL Server 2016 (SP2-CU11-GDR) (KB4535706) - 13.0.5622.0 (X64) Dec 15 2019 08:03:11 Copyright (c) Microsoft CorporationDeveloper Edition (64-bit) on Windows 10 Enterprise 10.0 <X64> (Build 18363: ) (Hypervisor)
    1 mssql_agentjob_MSSQLSERVER count=2 WARNING - job=[Fail Job 1];state=FAIL;runtime_min=0.00;runtime_check_min=200;\n job=[Fail Job 2];state=FAIL;runtime_min=0.00;runtime_check_min=200;\n 
    0 mssql_alwayson_MSSQLSERVER count=0 NA - Always-On is not available.;\n 
    1 mssql_backup_MSSQLSERVER count=7 WARNING - [master]; recovery_model=SIMPLE; last_full=2020-10-29 13:06:05; last_diff=NEVER; last_tran=NEVER;\n [model]; recovery_model=FULL; last_full=2020-10-29 13:06:06; last_diff=NEVER; last_tran=NEVER;\n [msdb]; recovery_model=SIMPLE; last_full=2020-10-29 13:06:06; last_diff=NEVER; last_tran=NEVER;\n [AdventureWorks2016]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [AdventureWorksDW2016]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [_dbaid]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [TestFG]; recovery_model=FULL; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n 
    0 mssql_database_MSSQLSERVER count=0 NA - 8 online; 0 restoring; 0 recovering;\n 
    1 mssql_integrity_MSSQLSERVER count=6 WARNING - database=[master]; last_checkdb=2020-05-27 10:40:28;\n database=[model]; last_checkdb=2020-05-27 10:40:29;\n database=[msdb]; last_checkdb=2020-05-27 10:40:29;\n database=[AdventureWorks2016]; last_checkdb=2019-08-02 17:13:47;\n database=[AdventureWorksDW2016]; last_checkdb=2019-08-02 17:13:49;\n database=[TestFG]; last_checkdb=NEVER;\n 
    0 mssql_logshipping_MSSQLSERVER count=0 NA - Logshipping is currently not configured.;\n 
    0 mssql_mirroring_MSSQLSERVER count=0 NA - Mirroring is currently not configured.;\n 
    0 mssql_capacity_combined_MSSQLSERVER 'C'=360003.00;549504.00;248727728.00;0;261164114.40 
    0 mssql_capacity_fg_MSSQLSERVER _dbaid_LOG; used=0.79; reserved=8.00; max=26161.00|_dbaid_ROWS_PRIMARY; used=5.25; reserved=8.00; max=26161.00|AdventureWorks2016_LOG; used=0.70; reserved=2.00; max=26155.00|AdventureWorks2016_ROWS_PRIMARY; used=205.44; reserved=207.63; max=26360.63


    Linux:
    pwsh -File /usr/lib/check_mk_agent/plugins/dbaid-checkmk.ps1

    Example output:
    
    0 mssql_MSSQLSERVER - Microsoft SQL Server 2017 (RTM-CU21) (KB4557397) - 14.0.3335.7 (X64) Jun 12 2020 20:39:00 Copyright (C) 2017 Microsoft CorporationDeveloper Edition (64-bit) on Linux (Ubuntu 16.04.6 LTS)
    0 mssql_agentjob_MSSQLSERVER count=0 NA - No agent job(s) enabled;;\n
    0 mssql_alwayson_MSSQLSERVER count=0 NA - Always-On is not available.;\n
    1 mssql_backup_MSSQLSERVER count=3 WARNING - [master]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [model]; recovery_model=FULL; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n [msdb]; recovery_model=SIMPLE; last_full=NEVER; last_diff=NEVER; last_tran=NEVER;\n
    0 mssql_database_MSSQLSERVER count=0 NA - 5 online; 0 restoring; 0 recovering;\n
    1 mssql_integrity_MSSQLSERVER count=3 WARNING - database=[master]; last_checkdb=NEVER;\n database=[model]; last_checkdb=NEVER;\n database=[msdb]; last_checkdb=NEVER;\n
    0 mssql_logshipping_MSSQLSERVER count=0 NA - Logshipping is currently not configured.;\n
    0 mssql_mirroring_MSSQLSERVER count=0 NA - Mirroring is currently not configured.;\n
    0 mssql_capacity_combined_MSSQLSERVER - Monitor unsupported by Linux SQL instance
    0 mssql_capacity_fg_MSSQLSERVER - Monitor unsupported by Linux SQL instance
    0 mssql_perfcounter_MSSQLSERVER - Monitor unsupported by Linux SQL instance

#>

<#  List of SQL Server instances to connect to.  #>
Param(
    [parameter(Mandatory=$false)]
    [string[]]$SqlServer = @("servername")
)
Set-Location $PSScriptRoot

if ($Env:PSModulePath -like "*\WindowsPowerShell\Modules*") {
    $IsThisWindows = 1
}
else {
    $IsThisWindows = 0
}

<##### Get credentials to connect to SQL Server (Linux only; Windows uses service account of CheckMK Agent service) #####>
if ($IsThisWindows -eq 0) {
    $HexPass = Get-Content "/usr/share/check-mk-agent/plugins/dbaid-checkmk.cred"
    $Credential = New-Object -TypeName PSCredential -ArgumentList "_dbaid_checkmk", ($HexPass | ConvertTo-SecureString)
}

<#  Loop through the SQL instances one by one.  #>
foreach ($Instance in $SqlServer) {
try {
    <#  Database holding required procedures to run for checks.  #>
    [string]$Database = '_dbaid'
    
    <#  Reset variable to null otherwise catch block returns incorrect value.  #>
    [string]$InstanceName = $null

    <#
        The next bit will get tripped up if you are trying to run this script on one machine but connecting to a SQL instance running on another machine.
        But then as per .DESCRIPTION above, this script is supposed to be executed on the machine that SQL Server is installed on.
        We could test for this, but this in turn would get tripped up by instances running in Docker containers (example scenario being multiple instances on a single Linux host; can't do named instances otherwise).
          The SERVERPROPERTY('ComputerNamePhysicalNetBIOS') function on a SQL instance in a Docker container returns the name assigned to the Docker container, not the Linux host name.
          The check_mk_agent runs on the Linux host, not within the Docker container, so $Env:HOSTNAME will return the host name, not the Docker container name.
    #>

    <#  If running PowerShell 6 or higher, could use system $IsWindows. Lowest requirement for this script to work, however, is PowerShell 5. Can revisit in the future.  #>
    if ($IsThisWindows -eq 1) {
        <#  Check if this is a clustered SQL instance. #>
        $IsClustered = Invoke-SqlCmd -ServerInstance $Instance -Query "SELECT CAST(SERVERPROPERTY('IsClustered') AS bit) AS [IsClustered]"
        
        <#  Get NetBIOS name according to SQL Server. I.e. computer name that SQL instance is running on.  #>
        $NetBIOSName = Invoke-SqlCmd -ServerInstance $Instance -Query "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [NetBIOSName]"

        <#  Get computer name according to PowerShell. This may be different than what SQL Server thinks if SQL Server is clustered.  #>
        $ComputerName = $env:computername

        <#  If computer name & NetBIOS name don't match and SQL instance is clustered, this script is running on the passive node for this SQL instance; so don't run the SQL checks, they'll be run on the active node.  #>
        if ($ComputerName.ToUpper() -ne $NetBIOSName.NetBIOSName.ToUpper() -and $IsClustered.IsClustered -eq 1) {
            continue
        }
    }

    <#  Get list of procedures to run for checks. All should be in the [checkmk] schema.  #>
    if ($IsThisWindows -eq 1) {
        $CheckProcedureList = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'check%'").proc
        $ChartProcedureList = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'chart%'").proc
        $InventoryProcedureList = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'inventory%'").proc
    }
    else {
        $CheckProcedureList = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'check%'").proc
        $ChartProcedureList = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'chart%'").proc
        $InventoryProcedureList = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "SELECT [proc]=QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM [sys].[objects] WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND [name] LIKE N'inventory%'").proc
    }

    <#  Get SQL Server version information. Pass through function to remove invalid characters and have on one line for CheckMK to handle it.  #>
    if ($IsThisWindows -eq 1) {
        $InstanceVersion = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "SELECT [clean_string] AS [InstanceVersion] FROM [system].[get_clean_string](@@VERSION)").InstanceVersion
    }
    else {
        $InstanceVersion = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "SELECT [clean_string] AS [InstanceVersion] FROM [system].[get_clean_string](@@VERSION)").InstanceVersion
    }

    <#  Refresh check configuration (i.e. to pick up any new jobs or databases added since last check).  #>
    foreach ($iproc in $InventoryProcedureList) {
        if ($IsThisWindows -eq 1) {
            Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "EXEC $iproc" -OutputAs DataSet
        }
        else {
            Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "EXEC $iproc" -OutputAs DataSet
        }
    }
    
    <#  Get SQL instance name. Used in output as part of CheckMK service name.  #>
    if ($IsThisWindows -eq 1) {
        $InstanceName = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "SELECT ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS [InstanceName]").InstanceName
    }
    else {
        $InstanceName = (Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "SELECT ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS [InstanceName]").InstanceName
    }
    
    <#  Output SQL Server instance information in CheckMK format.  #>
    Write-Host "0 mssql_$($InstanceName) - $($InstanceVersion)"
    
    <#  Process each check procedure in the [checkmk] schema.  #>
    foreach ($ckproc in $CheckProcedureList) {
        <#  Pull part of procedure name to use in CheckMK service name.  #>
        $ServiceName = $ckproc.Substring($ckproc.IndexOf('_') + 1).Replace(']','')

        <#  Execute procedure, store results in dataset variable (i.e. PowerShell table equivalent).  #>
        if ($IsThisWindows -eq 1) {
            $ckDataSet = Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "EXEC $ckproc" -OutputAs DataSet
        }
        else {
            $ckDataSet = Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "EXEC $ckproc" -OutputAs DataSet
        }

        <#  Get rowcount of dataset variable. If the top row returned has [state] value of 'NA', then set count=0 (i.e. monitor doesn't apply, nothing wrong detected). If there's more than one row returned, there's probably a fault.  #>
        $Count = $ckDataSet.Tables[0].Rows.Count
        $Count = Switch($ckDataSet.Tables[0].Rows[0].state){'NA'{0} default{$Count}}

        <#  Get status for the monitor as indicated by value in [state] column.  #>
        $Status = Switch($ckDataSet.Tables[0].Rows[0].state){ 'NA'{0} 'OK'{0} 'WARNING'{1} 'CRITICAL'{2} default{3}}

        <#  Initialize variables for storing state & status detail strings.  #>
        [string]$StatusDetails = ""
        [string]$State = ""

        foreach ($ckrow in $ckDataSet.Tables[0].Rows) {
            $StatusDetails += $ckrow.message + ";\n "
            $State = $ckrow.state
        }

        <#  Write output for CheckMK agent to consume.  #>
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
    
        <#  Pull part of procedure name to use in CheckMK service name.  #>
        $ServiceName = $ctproc.Substring($ctproc.IndexOf('_') + 1).Replace(']','')

        <#  Execute procedure, store results in dataset variable (i.e. PowerShell table equivalent).  #>
        if ($IsThisWindows -eq 1) {
            $ctDataSet = Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Query "EXEC $ctproc" -As DataSet
        }
        else {
            $ctDataSet = Invoke-SqlCmd -ServerInstance $Instance -Database $Database -Credential $Credential -Query "EXEC $ctproc" -As DataSet
        }

        foreach ($ctrow in $ctDataset.Tables[0].Rows) {
            <#  Variables to manage pnp chart data. Initialize for each row of data being processed (i.e. each database or performance monitor counter).  #>
            [bool]$WarnExist = 0
            [bool]$CritExist = 0
            [decimal]$val = 0.0
            [decimal]$warn = 0.0
            [decimal]$crit = 0.0

            <#  Check for current value, warning threshold, critical threshold, pnp chart data.  #>
            <#  chart_capacity_fg has different columns returned compared to anything else, so has its own code to handle data.  #>
            if ($ctproc -ne "[checkmk].[chart_capacity_fg]") {
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

                <#  Concatenate all the pnp data into one text string for CheckMK to consume. Use pipe separator for subsequent rows being concatenated.  #>
                if ($row -eq 0) {
                    $StatusDetails += $ctrow.pnp
                }
                else {
                    $StatusDetails += "|" + $ctrow.pnp
                }
            }
            else {
                <#  There is only [checkmk].[chart_capacity_fg] at time of writing. The code below may not be suitable if other chart procedures are created and don't/can't conform to same output.  #>
                if (([DBNull]::Value).Equals($ctrow.used)) { 
                    $val = -1.0
                }
                else {
                    $val = $ctrow.used
                }
                if (([DBNull]::Value).Equals($ctrow.warning)) { 
                    $WarnExist = 0
                    $warn = 0.0
                }
                else {
                    $WarnExist = 1
                    $warn = $ctrow.warning
                }
                if (([DBNull]::Value).Equals($ctrow.critical)) { 
                    $CritExist = 0
                    $crit = 0.0
                }
                else {
                    $CritExist = 1
                    $crit = $ctrow.critical
                }
                if (([DBNull]::Value).Equals($ctrow.message)) { 
                    $pnpData = ""
                }
                else {
                    $pnpData = $ctrow.message
                }

                <#  If there is no chart data, skip the rest and move to next row in the data set.  #>
                if ($pnpData -eq "" -and $val -eq -1.0) {
                    continue
                }

                <#  Check to see if warning and critical thresholds are defined, then check current value $val against threshold values for warning $warn and critical $crit.  #>
                if ($CritExist -and $WarnExist) {
                    if ($crit -ge $warn) {
                        if ($val -ge $crit) {
                            <#  Split the pnp data at the '=' character to form a new array, take the first element of the new array [0] which amounts to the object exceeding a threshold (e.g. dbname_ROWS_used) and remove the single quote characters.  #>
                            $State += "CRITICAL - " + ($ctrow.message).Split('=')[0].Replace("'", "") + "; "
                            $Status = 2
                        }
                        elseif ($val -ge $warn -and $Status -lt 2) {
                            $State += "WARNING - " + ($ctrow.message).Split('=')[0].Replace("'", "") + "; "
                            $Status = 1
                        }
                    }
                }
                elseif ($crit -lt $warn) {
                    if ($val -le $crit) {
                        $State += "CRITICAL - " + ($ctrow.message).Split('=')[0].Replace("'", "") + "; "
                        $Status = 2
                    }
                    elseif ($val -le $warn -and $Status -lt 2) {
                        $State += "WARNING - " + ($ctrow.message).Split('=')[0].Replace("'", "") + "; "
                        $Status = 1
                    }
                }

                <#  Concatenate all the pnp data into one text string for CheckMK to consume. Use pipe separator for subsequent rows being concatenated.  #>
                if ($row -eq 0) {
                    $StatusDetails += $ctrow.message
                }
                else {
                    $StatusDetails += "|" + $ctrow.message
                }
            }
            $row++
        }

        <#  Write output for CheckMK agent to consume.  #>
        Write-Host "$Status mssql_$($ServiceName)_$($InstanceName) $StatusDetails $State"
    }
}
catch {
    <#  Work out the instance name based on name provided as we may not have been able to connect.  #>
    if ($null -eq $InstanceName) {
        $InstanceName = $Instance.ToUpper().Split('\')[1]  # element [0] is machine name, element [1] is instance name.  NB - MAY GET ODDITY IF "SERVER\INSTANCE,1234" IS PASSED
        if ($null -eq $InstanceName) {
            $InstanceName = 'MSSQLSERVER'
        }
        <#  Strip off any additional parameters passed in with server\instance name (e.g. -EncryptConnection) if they were specified. They're not part of the instance name.  #>
        $InstanceName = $InstanceName.Split(' ')[0]  # element [0] is instance name, elements [1..N] we don't care about
    }

    <#  Write output for CheckMK agent to consume.  #>
    Write-Host "2 mssql_$($InstanceName) - CRITICAL - Unable to run SQL Server checks. Check the following: Name is correct in dbaid-checkmk.ps1, SQL Server is running, permissions are granted to CheckMK service account in SQL Server."

    #<#  Extra debug information used when writing/troubleshooting script. 
    Write-Host $_
    Write-Host $_.ScriptStackTrace
    #>
}
finally {
    <#  Clean up the variables rather than waiting for .NET garbage collector.  #>
    If (Test-Path variable:local:HexPass) { Remove-Variable HexPass }
    If (Test-Path variable:local:Credential) { Remove-Variable Credential }
    If (Test-Path variable:local:IsThisWindows) { Remove-Variable IsThisWindows }
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