#New-SelfSignedCertificate -DnsName waynet@datacom.co.nz -CertStoreLocation Cert:\CurrentUser\My\ -Type Codesigning

Set-AuthenticodeSignature -FilePath ".\configg\bin\Release\export-configg-report.ps1" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)
Set-AuthenticodeSignature -FilePath ".\collector\bin\Release\comcryptor.ps1" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)
Set-AuthenticodeSignature -FilePath ".\checkmk\bin\Release\dbaid.checkmk.exe" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)
Set-AuthenticodeSignature -FilePath ".\collector\bin\Release\dbaid.collector.exe" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)
Set-AuthenticodeSignature -FilePath ".\configg\bin\Release\dbaid.configg.exe" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)

# Now you must import the certificate into Trusted Root Certification Authorities and Trusted Publishers