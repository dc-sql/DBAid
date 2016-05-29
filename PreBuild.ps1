  
  
  
  [string]$pathToSearch = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
  [string]$buildNumber = "`"12345`""
  [string]$pattern = "`\b`"[0-9][0-9][0-9][0-9][0-9]`\b`""
  [string]$searchFilter = "AssemblyInfo.*"
 
try
{
        gci -Path $pathToSearch -Filter $searchFilter -Recurse | %{
        Write-Host "  -> Changing $($_.FullName)"
         
            # remove the read-only bit on the file
            sp $_.FullName IsReadOnly $false
 
            # run the regex replace
            (gc $_.FullName) | % { $_ -replace $pattern, $buildNumber } | sc $_.FullName
 
        #Write-Host "Done!"
    }
}
catch {
    Write-Host $_
    exit 1
}