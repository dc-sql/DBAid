# Must execute script as Administrator
[array]$SqlServers = @()
 
if (Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name LIKE '%ClusSvc%'") { 
    Import-Module FailoverClusters
 
    $_clus = Get-ClusterResource -cluster (Get-Cluster).Name | Where { $_.ResourceType -like "SQL Server" } `
        | ForEach { ($_ | Get-ClusterParameter VirtualServerName, InstanceName | Select Value).Value -Join '\' }
 
    foreach ($_i in $_clus) {
        $SqlServers += [pscustomobject]@{host=$_i.Split('\')[0]; instance=$_i.Split('\')[1]; port=''}
    }
} 
 
[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
$_mc = new-object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
$_si = $_mc.ServerInstances
 
foreach ($_i in $_si) {
    $_host = $_i.Parent.Name
    $_instance = $_i.Name
    $_port = $_i.ServerProtocols['Tcp'].IPAddresses['IPAll'].IPAddressProperties['TcpPort'].Value
    
    if ($SqlServers.Count -gt 0) {
        if ($SqlServers.instance.Contains($_instance)) {
            if (-not $SqlServers.Where({ $_.instance -ieq $_instance }).port) {
                $SqlServers.Where({ $_.instance -ieq $_instance }) | Add-Member -MemberType NoteProperty -Name 'port' -Value $_port -Force
            }
        } else {
            [pscustomobject]@{host=$_host; instance=$_instance; port=$_port}
        }
    } else {
        [pscustomobject]@{host=$_host; instance=$_instance; port=$_port}
    }
}
 
$SqlServers
