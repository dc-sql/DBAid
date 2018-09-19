CD $PSScriptRoot

# Update submodules
git submodule foreach git pull origin master

# Download latest who_is_active
$url = 'http://whoisactive.com/downloads/'
$file = (Invoke-WebRequest -Uri $url).Links.href | Where { $_ -ilike '*who_is_active_*' } | Sort-Object -Descending | Select -First 1
Invoke-WebRequest -Uri ($url + $file) -OutFile ".\$file"
Expand-Archive -LiteralPath ".\$file" -DestinationPath ".\who-is-active" -Force
Rename-Item -Path (Get-ChildItem -Path ".\who-is-active" -File).FullName -NewName 'who_is_active.sql'
Remove-Item -Path ".\$file"