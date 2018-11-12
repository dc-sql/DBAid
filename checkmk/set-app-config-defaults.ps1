# Must execute script as Administrator
$AppConfig = Get-ChildItem -Path . -Filter '*.exe.config'
[xml]$AppConfigContent = $AppConfig | Get-Content

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
 
foreach ($i in $SqlServers) {
    $DataSource = (Join-Path $i.host $i.instance)
    $Port = $i.port
    $Name = $DataSource.Replace('\','@')
    $Smo = new-object ('Microsoft.SqlServer.Management.Smo.Server') $DataSource
    $Smo.ConnectionContext.ConnectTimeout = 1

    try { 
        $Smo.ConnectionContext.Connect()
        if (-not $Smo.ConnectionContext.IsOpen) { continue }
        if (-not $Smo.Databases.Contains('_dbaid')) { continue }
    }
    catch { continue }
    finally { $Smo.ConnectionContext.Disconnect() }

    if ($Port) {
        $ConnectionString = "Server=$DataSource,$Port;Database=_dbaid;Trusted_Connection=True;"
    } else {
        $ConnectionString = "Server=$DataSource;Database=_dbaid;Trusted_Connection=True;"
    }

    if ($AppConfigContent.configuration.connectionStrings) {
        if ($AppConfigContent.configuration.connectionStrings.add.Name -inotcontains $Name) {
            $NewConnection = $AppConfigContent.CreateElement("add")
            $NewConnection.SetAttribute("name",$Name);
            $NewConnection.SetAttribute("connectionString",$ConnectionString);
            $AppConfigContent.configuration.connectionStrings.AppendChild($NewConnection)
        }
    }
}

$AppConfigContent.Save($AppConfig.FullName)