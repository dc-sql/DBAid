#New-SelfSignedCertificate -DnsName waynet@datacom.co.nz -CertStoreLocation Cert:\CurrentUser\My\ -Type Codesigning

Set-AuthenticodeSignature -FilePath ".\configg\export-configg-report.ps1" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)
Set-AuthenticodeSignature -FilePath ".\collector\comcryptor.ps1" -Certificate (Get-ChildItem -Path Cert:\CurrentUser\My\ -CodeSigningCert)

# Now you must import the certificate into Trusted Root Certification Authorities and Trusted Publishers