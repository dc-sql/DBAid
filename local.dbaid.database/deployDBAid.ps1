#######################################################################
# DBAid deployment script
#
# Expected source folder structure example:
# 
# C:\temp\DBAid-build-6.5.0
#        \check_mk
#        \database
#        \Datacom
#        \DBAid
#
# Root folder can be different, (just update $SourceRootFolder below), 
#   but the 4 subfolders must remain the same.
#
# Not tested with clusters. Intended for standalone instances.
#
#######################################################################

# set variables
$deploy_collector = 1                        # deploy dbaid collector: 1 = Yes, 0 = No
$deploy_configg = 1                          # deploy config genie: 1 = Yes, 0 = No
# Choose one of the Checkmk deployment options below. VBS is default as per advice at https://docs.checkmk.com/latest/en/dev_guidelines.html#_agent_plug_ins
$deploy_checkmk_vbs = 1                      # deploy checkmk VBScript plugin: 1 = Yes, 0 = No
$deploy_checkmk_ps1 = 0                      # deploy checkmk PowerShell plugin: 1 = Yes, 0 = No
$hostname = $env:computername                # If this is a clustered SQL instance, change this to $hostname = "<VNN of SQL instance>"
$SQLInstance = "MSSQLSERVER"                 # SQL instance to deploy to. MSSQLSERVER = default instance.
$dbaid_db_name = "_dbaid"                    # Name of database to deploy dbaid to. Best if this is left as default of _dbaid
$SourceRootFolder = "C:\temp"                # Folder in which source DBAid folder structure is in
$DBAid_src = "$SourceRootFolder\DBAid-build-6.5.0" # Root folder for dbaid source files.
$dest_root = "C:"                            # Root drive to deploy dbaid executables to.

$checkmk_svc = "NT AUTHORITY\SYSTEM"         # Service account to use for Checkmk plugin (should be same as Check_MK_Agent Windows service)
$collector_svc = "NT AUTHORITY\SYSTEM"       # Service account to use for dbaid.collector. Only required if not running dbaid.collector from SQL Agent.
$client_domain = "@domain.co.nz"             # Domain name (FQDN) client machine is in
$publickey = "<RSAKeyValue><Modulus>blahblahblah</Modulus><Exponent>KFLR</Exponent></RSAKeyValue>"
$EmailEnable = "false"                       # Collector to email files? true/false
$EmailSmtp = "mailhost.domain.co.nz"         # Mail relay host for sending emails
$EmailTo = "recipient@domain.co.nz"          # Who to send collector files to
$EmailFrom = "$hostname@domain.co.nz"        # Who the collector files came from (usually <hostname|VNN@domain.co.nz)
$Tenant = "Tenant"                           # Customer/tenant/site being monitored. Stored in [dbo].[static_parameters] table. Used in Checkmk monitors to identify configuration items.

# set standard destination folders
$collector_dest = "$dest_root\DBAid"                       # Folder for dbaid.collector.
$configg_dest = "$dest_root\Datacom"                       # Folder for config genie.
$checkmk_dest = "${env:ProgramFiles(x86)}\check_mk\local"  # Folder for Checkmk agent. Would be "${env:ProgramData}\checkmk\agent\local" for Checkmk 1.6 and above.

# set source files/folders
$collector_config = "dbaid.collector.exe.config"                # Config file for dbaid.collector.
$checkmk_vbscript = "dbaid-checkmk.vbs"                         # Checkmk plugin (VBScript format)
$checkmk_powershell = "dbaid-checkmk.ps1"                       # Checkmk plugin (PowerShell format)
$DBAid_collector_src = "$DBAid_src\DBAid"                       # Subfolder for dbaid.collector files.
$DBAid_configg_src = "$DBAid_src\Datacom"                       # Subfolder for dbaid.configg files.
$DBAid_checkmk_src = "$DBAid_src\check_mk"                      # Subfolder for dbaid.checkmk files.
$DBAid_db_src = "$DBAid_src\database\dbaid_release_Create.sql"  # SQL script to create dbaid database & objects therein.


#####################################
#                                   #
#  Check provided paths             #
#                                   #
#####################################
Write-Host "Checking provided paths..." -ForegroundColor Yellow

if ((!(Test-Path -Path $checkmk_dest)) -and ($deploy_checkmk -eq 1)) {
  Write-Host "Error! Folder $checkmk_dest does not exist (check_mk plugin folder)" -ForegroundColor Red
  Exit
}

if (!(Test-Path -Path $SourceRootFolder)) {
  Write-Host "Error! Folder $SourceRootFolder does not exist (root folder for source files)" -ForegroundColor Red
  Exit
}

if (!(Test-Path -Path $DBAid_src)) {
  Write-Host "Error! Folder $DBAid_src does not exist (source folder for dbaid executables)" -ForegroundColor Red
  Exit
}



#####################################
#                                   #
#  Check provided service accounts  #
#                                   #
#####################################
Write-Host "Checking provided service accounts..." -ForegroundColor Yellow

# assuming domain of account is same as domin of machine
if ($collector_svc -ine "NT AUTHORITY\SYSTEM") {
  if (!(dsquery user -samid $collector_svc.Substring($collector_svc.IndexOf("\") + 1))) {
    Write-Host "Error! User $collector_svc does not exist (collector service account)" -ForegroundColor Red
    Exit
  }
}

if ($checkmk_svc -ine "NT AUTHORITY\SYSTEM") {
  if (!(dsquery user -samid $checkmk_svc.Substring($checkmk_svc.IndexOf("\") + 1))) {
    Write-Host "Error! User $checkmk_svc does not exist (collector service account)" -ForegroundColor Red
    Exit
  }
}


#####################################
#                                   #
#  Check SQL Server is running      #
#                                   #
#####################################
Write-Host "Checking SQL Server instance is running..." -ForegroundColor Yellow

if ($SQLInstance -eq "MSSQLSERVER") {
  $SQLService = "MSSQLSERVER"
}
else {
  $SQLService = "MSSQL$" + $SQLInstance
}

if (!(Get-Service | Where-Object { $_.Name -ieq $SQLService })) {
  Write-Host "Error! Cannot find matching SQL Server service for instance [$SQLInstance]" -ForegroundColor Red
  Exit
}
elseif (Get-Service | Where-Object { $_.Name -ieq $SQLService -and $_.Status -ine "Running" }) {
  Write-Host "Error! SQL Instance [$SQLInstance] isn't running" -ForegroundColor Red
  Exit
}





#####################################
#                                   #
#  Copy DBAid collector to C: drive #
#                                   #
#####################################
Write-Host "Deploying DBAid collector..." -ForegroundColor Yellow

# check if it already exists - if this is an installation to a second instance, just add new connection string.
# if this is upgrade stuff, use the upgrade script! This script will just add connection strings to whatever config file it finds.
try {
  if ($deploy_collector -eq 1) {
    if ($SQLInstance -eq "MSSQLSERVER") {
      $servername = $hostname
      $connectionstring = "Server=$hostname;Database=$dbaid_db_name;Trusted_Connection=True;Application Name=DBAid Collector;"
    }
    else {
      $servername = "$hostname@$SQLInstance"
      $connectionstring = "Server=$hostname\$SQLInstance;Database=$dbaid_db_name;Trusted_Connection=True;Application Name=DBAid Collector;"
    }
    
    # is there already a config file (i.e. collector already deployed)? If so, update existing file.
    if (Test-Path -Path $collector_dest\$collector_config) {
      # read existing config file
      [xml]$config = Get-Content "$collector_dest\$collector_config" -Raw
      
      # add new connection string
      if ($config.configuration.connectionStrings.add.name -ine $servername) {
        $newconnection = $config.CreateElement("add")
        $newconnection.SetAttribute("name", $servername)
        $newconnection.SetAttribute("connectionString", $connectionstring)
        $config.configuration.connectionStrings.AppendChild($newconnection) | Out-Null
        # save changes to new config file
        $config.Save("$collector_dest\$collector_config")
      } 
    }
    # if no existing config file found, clean install.
    else {
      # copy folder & files, grant permissions to collector service account (required for log/processed file cleanup)
      Copy-Item $DBAid_collector_src $collector_dest -Recurse -Force
      $Acl = Get-Acl $collector_dest
      $Acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($collector_svc,"Modify","ContainerInherit, ObjectInherit","None","Allow")))
      Set-Acl $collector_dest $Acl
      
      # pull contents of configuration file into variable
      [xml]$config = Get-Content "$collector_dest\$collector_config" -Raw

      # remove default connection strings from new config file
      $node = $config.SelectSingleNode("/configuration/connectionStrings/add")

      while ($null -ne $node) {
        $node.ParentNode.RemoveChild($node) | Out-Null
        $node = $config.SelectSingleNode("/configuration/connectionStrings/add")
      }
      
      # insert new connection string
      if ($config.configuration.connectionStrings.add.name -ine $servername) {
        $newconnection = $config.CreateElement("add")
        $newconnection.SetAttribute("name", $servername)
        $newconnection.SetAttribute("connectionString", $connectionstring)
        $config.configuration.connectionStrings.AppendChild($newconnection) | Out-Null
      }
      
      # insert email settings
      # assuming these are going to be the same for each installation (this entire script run for each SQL instance)
      foreach ($setting in $config.configuration.appSettings.add) {
        $setting_enable = $config.SelectSingleNode("/configuration/appSettings/add[@key='EmailEnable']")
        $setting_enable.SetAttribute("value", $EmailEnable)
        $setting_smtp = $config.SelectSingleNode("/configuration/appSettings/add[@key='EmailSmtp']")
        $setting_smtp.SetAttribute("value", $EmailSmtp)
        $setting_to = $config.SelectSingleNode("/configuration/appSettings/add[@key='EmailTo']")
        $setting_to.SetAttribute("value", $EmailTo)
        $setting_from = $config.SelectSingleNode("/configuration/appSettings/add[@key='EmailFrom']")
        $setting_from.SetAttribute("value", $EmailFrom)
      }

      # save changes to new config file
      $config.Save("$collector_dest\$collector_config")
    }
  }
}
catch {
  Write-Host "Some sort of terminating error deploying DBAid collector." -ForegroundColor Red
  $error
  Exit
}
    
#####################################
#                                   #
#  Copy DBAid configg to C: drive   #
#                                   #
#####################################
Write-Host "Deploying DBAid Config Genie..." -ForegroundColor Yellow

# copy new file
try {
  if ($deploy_configg -eq 1) {
    Copy-Item $DBAid_configg_src "$dest_root\" -Recurse -Force
  }
}
catch {
  Write-Host "Some sort of terminating error deploying DBAid Config Genie." -ForegroundColor Red
  $error
  Exit
}



#####################################
#                                   #
#  Copy check_mk plugin             #
#                                   #
#####################################
Write-Host "Deploying DBAid Check_MK plugin..." -ForegroundColor Yellow

try {
  if ($deploy_checkmk_vbs -eq 1) {
    if ($SQLInstance -eq "MSSQLSERVER") {
      $servername = -join("`"",$hostname,"`"")
    }
    else {
      $servername = -join("`"",$hostname,"\",$SQLInstance,"`"")
    }

    if (Test-Path -Path $checkmk_dest\$checkmk_vbscript) {
      # read existing plugin script
      $content = Get-Content "$checkmk_dest\$checkmk_vbscript" -Raw

      # add new connection string. Find by looking for declaration at top of script, capturing existing instances specified, appending new one.
      # this doesn't check if the current deployment matches what's already in the connection strings (e.g. when upgrading), so can end up doubling output. Another time...
      $startcurrentserverlistindex = ($content).IndexOf("v_SQLInstances = Array(`"") + 23
      $endcurrentserverlistindex = ($content).IndexOf("`")")
      $currentserverlistlength = $endcurrentserverlistindex - $startcurrentserverlistindex + 1
      $currentserverliststring = ($content).Substring($startcurrentserverlistindex, $currentserverlistlength)
      $newserverliststring = -join ($currentserverliststring, ",", $servername)
      $content = ($content).Replace($currentserverliststring, $newserverliststring)

      # save changes to plugin script
      $content | Set-Content "$checkmk_dest\$checkmk_vbscript" -Encoding ASCII
    }
    else {
      # copy plugin script
      Copy-Item "$DBAid_checkmk_src\$checkmk_vbscript" $checkmk_dest -Recurse -Force

      # read plugin script
      $content = Get-Content "$checkmk_dest\$checkmk_vbscript" -Raw

      # add connection string to plugin script
      $content = ($content).Replace("v_SQLInstances = Array(`"localhost`")","v_SQLInstances = Array($servername)")
      
      # save changes to plugin script
      $content | Set-Content "$checkmk_dest\$checkmk_vbscript" -Encoding ASCII
      
    }
    
  }
  elseif ($deploy_checkmk_ps1 -eq 1) {
    if ($SQLInstance -eq "MSSQLSERVER") {
      $connectionstring = "$hostname;"
    }
    else {
      $connectionstring = "$hostname\$SQLInstance;"
    }

    if (Test-Path -Path $checkmk_dest\$checkmk_powershell) {
      # read existing plugin script
      $content = Get-Content "$checkmk_dest\$checkmk_powershell" -Raw

      # add new connection string. Find by looking for declaration at top of script, capturing existing instances specified, appending new one.
      # this doesn't check if the current deployment matches what's already in the connection strings (e.g. when upgrading), so can end up doubling output. Another time...
      $startcurrentserverlistindex = ($content).LastIndexOf('[string[]]$SqlServer = @(') + 25
      $endcurrentserverlistindex = ($content).IndexOf('") # Add more as required.')
      $currentserverlistlength = $endcurrentserverlistindex - $startcurrentserverlistindex + 1
      $currentserverliststring = ($content).Substring($startcurrentserverlistindex, $currentserverlistlength)
      $newserverliststring = -join ($currentserverliststring, ",", "`"Data Source=",$connectionstring,"`"")
      $content = ($content).Replace("$currentserverliststring", "$newserverliststring")

      # save changes to plugin script
      $content | Set-Content "$checkmk_dest\$checkmk_powershell" -Encoding UTF8
    }
    else {
      # copy plugin script
      Copy-Item "$DBAid_checkmk_src\$checkmk_powershell" $checkmk_dest -Recurse -Force

      # read plugin script
      $content = Get-Content "$checkmk_dest\$checkmk_powershell" -Raw

      # add connection string to plugin script
      $content = ($content).Replace("[string[]]`$SqlServer = @(`"Data Source=localhost;`")","[string[]]`$SqlServer = @(`"Data Source=$connectionstring`") # Add more as required.")
      
      # save changes to plugin script
      $content | Set-Content "$checkmk_dest\$checkmk_powershell" -Encoding UTF8
    }
  }
}
catch {
  Write-Host "Some sort of terminating error deploying DBAid Check_MK plugin." -ForegroundColor Red
  $error
  Exit
}



#####################################
#                                   #
#  Deploy DBAid DB                  #
#                                   #
#####################################
Write-Host "Deploying DBAid database..." -ForegroundColor Yellow

try{
  # if there are multiple instances per machine, assuming same collector/checkmk accounts for each (which is how it's usually done).
  $content = Get-Content $DBAid_db_src -Raw

  # set service accounts
  if ($checkmk_svc -ine "NT AUTHORITY\SYSTEM") {
    $content = ($content) -Replace(":setvar CheckServiceAccount `"NT AUTHORITY\\SYSTEM`"",":setvar CheckServiceAccount `"$checkmk_svc`"")
  }
  if ($collector_svc -ine "NT AUTHORITY\SYSTEM") {
    $content = ($content) -Replace(":setvar CollectorServiceAccount `"NT AUTHORITY\\SYSTEM`"",":setvar CollectorServiceAccount `"$collector_svc`"")
  }

  # add public key
  # NB - looks for default value to replace. If you've got a different public key in your database deployment script already, it won't get replaced!
  $content = ($content) -Replace(":setvar PublicKey `"Generate public key using CLR project dbaid.keygen`"",":setvar PublicKey `"$publickey`"")

  # set client domain
  # NB - looks for default values to replace. If you've changed the defaults, they won't get updated.
  $content = ($content) -Replace(":setvar ClientDomain `"@domain.co.nz`"",":setvar ClientDomain `"$client_domain`"")
  $content = ($content) -Replace(":setvar DatabaseName `"_dbaid`"",":setvar DatabaseName `"$dbaid_db_name`"")
  $content = ($content) -Replace(":setvar ServiceLoadExe `"_dbaid`"",":setvar ServiceLoadExe `"$configg_dest\dbaid.configg.exe`"")
  $content = ($content) -Replace(":setvar Tenant `"Tenant`"",":setvar Tenant `"$Tenant`"")

  # update file
  $content | Set-Content $DBAid_db_src -Encoding UTF8
   
  # deploy dbaid database & related objects
  $command = "sqlcmd"
  $arg1 = "-S"
  if ($SQLInstance -ieq "MSSQLSERVER") {
    $arg2 = "$hostname"
  }
  else {
    $arg2 = "$hostname\$SQLInstance"
  }
  $arg3 = "-E"
  $arg4 = "-i"
  $arg5 = "`"$DBAid_db_src`""

  & $command $arg1 $arg2 $arg3 $arg4 $arg5
}
catch {
  Write-Host "Some sort of terminating error deploying DBAid database." -ForegroundColor Red
  $error
  Exit
}

Write-Host "Deployment complete..." -ForegroundColor Green