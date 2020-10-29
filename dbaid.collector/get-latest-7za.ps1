[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
CD $PSScriptRoot
$Url = 'https://www.7-zip.org'
$Link = "$Url/" + ((Invoke-WebRequest –Uri "$Url/download.html").Links | Where { $_.innerHTML -ieq 'Download' -and $_.outerHTML -ilike '*-extra.7z*' } | Select -First 1).outerHTML.Split('"')[1]

if ($Link -match '\d\d\d\d') {
    $LatestVersion = $matches[0].Insert(2, '.')
}

$ExePath = Join-Path $PSScriptRoot '7za.exe'
$CurrentVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath).FileVersion

if ($LatestVersion -and $CurrentVersion) {
    if ($LatestVersion -ine $CurrentVersion) {
        Invoke-WebRequest -Uri $Link -OutFile '.\latest-7z-extra.7z'
        Rename-Item -Path '.\7za.exe' -NewName 'old.7za.exe' -Force

        $cmd = $ExePath.Replace('7za.exe','old.7za.exe')
        & .\old.7za.exe --% e latest-7z-extra.7z 7za.exe
        Remove-Item -Path 'old.7za.exe' -Force
	    Remove-Item -Path 'latest-7z-extra.7z' -Force
    } else {
        Write-Host "7za.exe is currently the latest version."
    }
}
 