CD $PSScriptRoot

# Update submodules
$ErrorActionPreference = "SilentlyContinue"
&git submodule update --init --recursive
&git submodule foreach git pull origin master 

Get-ChildItem -Path ".\sql-server-maintenance-solution" -Filter *.sql -Exclude MaintenanceSolution.sql -File -Recurse | Copy-Item -Destination ".\ola-maintenance-solution"

foreach($file in (Get-ChildItem -Path ".\ola-maintenance-solution" -File -Filter *.sql)) {
    [string[]]$content = Get-Content $file.FullName
    [bool]$isBegin = $false
    [string[]]$output = @()
    [char]$type = ' '
    [bool]$hasConstraints = $false
    [bool]$getNext = $false

    foreach($line in $content) {
        if ($line -ilike '*ALTER*TABLE*WITH*CHECK*ADD*CONSTRAINT*') {
            $hasConstraints = $true
        }
    }

    foreach($line in $content) {
        if ($line -ilike 'ALTER PROCEDURE *') {
            $line = $line.Replace('ALTER PROCEDURE ','CREATE PROCEDURE ')
            $type = 'P'
            $isBegin = $true
        }

        if ($line -ilike 'CREATE TABLE *') {
            $type = 'T'
            $isBegin = $true
        }

        if ($line -ilike '*ALTER*TABLE*WITH*CHECK*ADD*CONSTRAINT*') {
            $isBegin = $true
            $line = ',' + $line.Substring($line.IndexOf('CONSTRAINT'))
            $getNext = $true
        }

        if ($type -eq 'T' -and $line -eq 'END' -and $isBegin) {
            if ($hasConstraints) {
                $output.SetValue('',$output.Length-1);
            }

            $isBegin = $false
        }

        if ($isBegin -or $getNext) {
            if ($getNext) {
                if (-not $isBegin) {
                    $getNext = $false
                    $line = $line + ')'
                }
                $isBegin = $false
            }
            
            $output += $line
        }
    }

    Set-Content $file.FullName -Value $output -Force
}

# Download latest who_is_active
$url = 'http://whoisactive.com/downloads/'
$file = (Invoke-WebRequest -Uri $url).Links.href | Where { $_ -ilike '*who_is_active_*' } | Sort-Object -Descending | Select -First 1

if ((Get-ChildItem -Path ".\who-is-active" -File -Filter *.zip).Name -ieq $file) {
    Write-Host "Already have latest file"
} else {
    Get-ChildItem -Path ".\who-is-active" -File | Remove-Item -Force
    Invoke-WebRequest -Uri ($url + $file) -OutFile ".\who-is-active\$file" 
    Expand-Archive -LiteralPath ".\who-is-active\$file" -DestinationPath ".\who-is-active" -Force
    Rename-Item -Path (Get-ChildItem -Path ".\who-is-active" -File -Filter *.sql).FullName -NewName 'who_is_active.sql'
}