# Must execute script as Administrator
[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[system.reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
[array]$SqlServers = @()
[array]$Cluster = @()

if (Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name LIKE '%ClusSvc%'") { 
    Import-Module FailoverClusters
 
    $Cluster = Get-ClusterResource -cluster (Get-Cluster).Name | Where { $_.ResourceType -like "SQL Server" } `
        | ForEach { ($_ | Get-ClusterParameter VirtualServerName, InstanceName | Select Value).Value -Join '\' }
}

foreach ($i in (new-object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer).ServerInstances) {
    $SqlHost = $i.Parent.Name
    $SqlInstance = $i.Name
    $SqlPort = $i.ServerProtocols['Tcp'].IPAddresses['IPAll'].IPAddressProperties['TcpPort'].Value
    
    $SqlServers += [pscustomobject]@{host=$SqlHost; instance=$SqlInstance; port=$SqlPort}

    if ($Cluster.Where({ $_.Split('\')[1] -ieq $SqlInstance })) {
        $SqlHost = $Cluster.Where({ $_.Split('\')[1] -ieq $SqlInstance }).Split('\')[0]
        $SqlServers.Where({ $_.instance -ieq $SqlInstance }) | Add-Member -MemberType NoteProperty -Name 'host' -Value $SqlHost -Force
    }
}
 
$SqlServers | Select host, instance, port
