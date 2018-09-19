CD $PSScriptRoot

# Update submodules
git submodule foreach git pull origin master

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