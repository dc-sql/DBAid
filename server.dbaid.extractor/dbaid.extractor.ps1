<#
.SYNOPSIS
    DBAid Version 6.5.0
    This script is used to:
        - Download email attachments from a Microsoft 365 Exchange Online mailbox to server this script is run from.
        - Mark the processed emails as read.
        - Move the processed emails to a subfolder (usually one per customer).
        - Call the extractor script to decrypt the attachment files (also moving processed files to a subfolder).
        - Move the decrypted files to folders for processing by the Daily Checks SQL Agent job.

    This script requires:
     - PowerShell 7.
     - A copy of Microsoft.Exchange.WebServices.dll from https://www.nuget.org/packages/Microsoft.Exchange.WebServices.
     - dbaid.extractor.decryptor.ps1
    
.DESCRIPTION

    Copyright (C) 2015 Datacom
    GNU GENERAL PUBLIC LICENSE
    Version 3, 29 June 2007

    This script is part of the DBAid toolset.

    This script connects to the specified Exchange Online mailbox to download and process encrypted attachments sent by the DBAid Collector utility.

    It is intended that the script runs on the SQL Server instance that hosts the DailyChecks database.
    
    The script uses secured credentials to connect to the Exchange Online mailbox using Application (client) ID and Client Secret. These must be saved to XML file using Export-Clixml:
    
    # Use the App ID as UserName, Client Secret as Password
    $Credentials = Get-Credential
    $Credentials | Export-Clixml -Path <Path_to_folder_where_extractor_script_will_live>\dbaid.extractor.Mail_Collector_Credentials.xml -Confirm:$false 

.LINK
    DBAid source code: https://github.com/dc-sql/DBAid

.EXAMPLE
    Just edit the variables in the USER VARIABLES TO SET block and run the script.
#>

try {
    <# ######## START USER VARIABLES TO SET ######## #>

    # Mailbox that DBAid Collector emails are sent to.
    $MailboxAddress = "email@domain.com"

    # All DBAid Collector emails should have this subject.
    $MailboxSubjectFilter = "DBAid SQL Collector XML"

    # Folder that files are extracted to/decrypted in.
    $AttachmentRootFolder = "E:\DBAid_xml"
    $AttachmentFolder = -join ($AttachmentRootFolder, "\ExtractorWorkingDirectory")
    $StagingRootFolder = "E:\DBAid_xml"
    $StagingFolder = -join ($StagingRootFolder, "\Staging")

    # Folder that DBAid Extractor script is in.
    $ExtractorDirectory = "P:\DBAid_xml\dbaid.extractor.filesonly"

    # Script output log file location.
    $LogFilePath = -join ("$ExtractorDirectory\dbaid_extractor_",(Get-Date -Format "yyyyMMdd"),".log")
    $MaxAge = -14  # How many days old a log file is allowed to be before being deleted.

    # Directory (tenant) ID is from https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/AppID/c25e4294-bac6-4c87-8089-a71895b9e7bf/isMSAApp~/false
    $TenantID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

    <# ######## END USER VARIABLES TO SET ######## #>

    $Transcript = -join ("$ExtractorDirectory\dbaid_extractor_transcript_",(Get-Date -Format "yyyyMMdd"),".log")
    Start-Transcript $Transcript -Append -UseMinimalHeader | Out-Null
    # Define the Azure App settings (being the interface to the specified mailbox; app registration with scope of a specific mailbox).
    # Future enhancement: use a certificate rather than a client secret. Quite involved, so avoiding unless absolutely have to.
    # Load the client secret
    $Credentials = Import-Clixml -Path "$ExtractorDirectory\dbaid.extractor.Mail_Collector_Credentials.xml"
    $AppID = ($Credentials).UserName
    $ClientSecret = ($Credentials).Password | ConvertFrom-SecureString -AsPlainText

    # Define the EWS scope.
    $EWSScope = "https://outlook.office365.com/.default"

    # Load the required assembly to be able to use EWS API/methods/procedure calls.
    Add-Type -Path "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll"

    try {
        # Acquire an access token to connect to the EWS API associated with the mailbox we're going to access.
        $RequestBody = @{client_id=$AppID;client_secret=$ClientSecret;grant_type="client_credentials";scope=$EWSScope;}
        $OAuthResponse = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token -Body $RequestBody
        $AccessToken = $OAuthResponse.access_token

        # Configure the ExchangeService to connect with the access token we just acquired.
        $EWSClient = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService
        $EWSClient.Url = New-Object System.Uri("https://outlook.office365.com/EWS/Exchange.asmx")
        $EWSClient.Credentials = New-Object Microsoft.Exchange.WebServices.Data.OAuthCredentials($AccessToken)
        $EWSClient.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $MailboxAddress)

        # Set the context of our activities to the mailbox we want to access.
        $EWSClient.HttpHeaders.Add("X-AnchorMailbox", $MailboxAddress)

        # Set search filter. We only want unread mail items (stuff that hasn't been processed) with a particular subject line (in case some other email finds its way into the mailbox).
        $SrchFltrIsRead = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.EmailMessageSchema]::IsRead, $false)
        $SrchFltrSubj = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+ContainsSubstring ([Microsoft.Exchange.WebServices.Data.ItemSchema]::Subject, $MailboxSubjectFilter)
        $SrchFltrCollection = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+SearchFilterCollection([Microsoft.Exchange.WebServices.Data.LogicalOperator]::And);
        $SrchFltrCollection.Add($SrchFltrIsRead)
        $SrchFltrCollection.Add($SrchFltrSubj)

        # Now get a list of items from the inbox based on the filter criteria specified above.
        $MailItemsToProcess = $EWSClient.FindItems([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox, $SrchFltrCollection, (New-Object Microsoft.Exchange.WebServices.Data.ItemView(20000)))
        
        # Initialise output log file
        $ColHeaders = "DateTimeStamp | MailFrom | EmailSubject | LastAttachmentServerName | NumberAttachmentsInEmail | NumberAttachmentsSavedToFilesystem | Comments"
        if (-not (Test-Path $LogFilePath)) { $ColHeaders | Out-File -FilePath $LogFilePath -Append -Force }

        # Initialise variables for processing emails.
        [int]$AttachmentCounter = 0
        [string]$From = ""
        [string]$Subject = ""
        [int]$AttachmentSavedSuccessful = 0
        [int]$AttachmentNotSavedSuccessful = 0	
        
        # Get a list of subfolders; required later for moving read items out of inbox (in particular, need folderid to pass to Move method). Not expecting more than 100 subfolders.
        $InboxSubFolders = $EWSClient.FindFolders([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox, (New-Object Microsoft.Exchange.WebServices.Data.FolderView(100)))    

        # Loop through each item, downloading attachment to specified folder, marking email item as read, and moving to a subfolder.
        Write-Host "Downloading mail attachments..." -ForegroundColor Cyan
        foreach ($MailItem in $MailItemsToProcess.Items) {
        
            $MailItem.Load()
            $Subject = $MailItem.Subject.ToString()
            $From = $MailItem.From.Address 
            $AttachmentSavedSuccessful = 0
            $AttachmentCounter = 0
            $SaveErrorFileCollection = ""
            
            foreach ($Attachment in $MailItem.Attachments) {
            
                $Attachment.Load()
                $AttachName = $Attachment.Name
                $SavePathAndFileName = $AttachmentFolder + "\" + $Attachment.Name.ToString()
                
                try {
                    $File = New-Object System.IO.FileStream(($SavePathAndFileName), [System.IO.FileMode]::Create)
                    $File.Write($Attachment.Content, 0, $Attachment.Content.Length)
                    $File.Close()
                }
                catch {
                    $SaveErrorFileCollection = $SaveErrorFileCollection + ", " + $SavePathAndFileName
                    $SaveError = "Error saving $SaveErrorFileCollection, check that the path exists on the filesystem."
                    Write-Error $SaveError
                    Write-Host "Error Message: $_" -ForegroundColor Red
                }
            
                # Test that file has been saved successfully - if so, increment $AttachmentSavedSuccessful otherwise increment $AttachmentNotSavedSuccessful.
                if (Test-Path -Path $SavePathAndFileName){$AttachmentSavedSuccessful++} else {$AttachmentNotSavedSuccessful++}
                
                $AttachmentCounter++
            }
            
            try {
                # Mark item as read and move it out of inbox
                $MailItem.IsRead = $true
                $MailItem.Update([Microsoft.Exchange.WebServices.Data.ConflictResolutionMode]::AlwaysOverwrite)

                $TargetFolderID = $null
                
                # Determine where/who it came from. Get ID of target subfolder accordingly. Basically a mail rule.
                # Using AttachName as sender information (From) may not match where it actually came from, due to limitations of SMTP relay being used.
                # E.g., Emails from ClientX from servers in the CLIENT domain have a sender suffix of monitoring.domain.com instead of client.com 
                #       as they go through an SMTP relay on a separate/standalone monitoring server, not the CLIENT mail server.
                switch -RegEx ($AttachName) {
                    '.*customer1_domain_com.*' {
                        $TargetFolderID = ($InboxSubFolders | Where-Object{$_.Displayname -eq 'Customer1'}).ID
                        Break
                    }
                    '.*customer2_domain_com.*' {
                        $TargetFolderID = ($InboxSubFolders | Where-Object{$_.Displayname -eq 'Customer2'}).ID
                        Break
                    }
                    '.*customer3_domain_com.*' {
                        $TargetFolderID = ($InboxSubFolders | Where-Object{$_.Displayname -eq 'Customer3'}).ID
                        Break
                    }
                    '.*(customer4a_co_nz|customer4b_co_nz|customer4_local).*' {
                        $TargetFolderID = ($InboxSubFolders | Where-Object{$_.Displayname -eq 'Customer4'}).ID
                        Break
                    }
                    '.*(customer5_co_nz|(PRD|DR)(XXX|ZZZ)SQL\d\d).*' {
                        $TargetFolderID = ($InboxSubFolders | Where-Object{$_.Displayname -eq 'Customer5'}).ID
                        Break
                    }
                    Default { 
                        $TargetFolderID = $null 
                    }
                }
                
                # Now move it from inbox to correct/customer subfolder - unless a matching rule/folder wasn't found, in which case leave it in the inbox.
                if ($null -ne $TargetFolderID) {
                    $MailItem.Move([Microsoft.Exchange.WebServices.Data.FolderId] $TargetFolderID) | Out-Null
                }
            }
            catch {
                Write-Host "Error moving item to subfolder." -ForegroundColor Red
                Write-Host "Error Message: $_" -ForegroundColor Red
            }
            
            # Write processed mail detail out to log.
            $Comment = ""
            if ($iAttachmentSavedSuccessful -ne $iAttachmentCounter){$Comment = "Attachment(s) not saved. " + $SaveError}
            $DT = Get-Date -Format yyyyMMddhhmmss
            # For better logging, capture the server name in the last attachment processed.
            # Where DBAid Collector is centralised, all emails come from the same server name (From); not helpful if one email has issues while processing.
            if ($AttachName.Substring(0, 1) -eq "[") {
                $AttachName = $AttachName.Substring(1);
                $AttachName = $AttachName.Split(']')[0];
            }
            else {
                $AttachName = $AttachName.Split('_')[0];
            }
            "$DT|$From|$Subject|$AttachName|$AttachmentCounter|$AttachmentSavedSuccessful|$Comment" | Out-File -FilePath $LogFilePath -Append -Force
        }
    }
    catch {
        Write-Host "Error encountered with mail stuff." -ForegroundColor Red
        Write-Host "Error Message: $_" -ForegroundColor Red
    }

    # Decrypt the attachment files.
    # Have to call this portion from an older version of PowerShell (5.1) as the newer one (7) does not support BlockSize value required for call to crypto wossname RijndaelManaged.
    # Conversely, the connectivity to Exchange M365 only works from PowerShell 7.
    # So can't merge all this into one script until encryption routines used by DBAid Collector are uplifted. 
    # Which is a whole other issue, depending on what PowerShell versions are available on client servers (newer servers should have 5.1 at least; PowerShell 7 is a separate install).
    & "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe" -file "$ExtractorDirectory\dbaid.extractor.decryptor.ps1" 

    # Move the files (overwriting any existing files with same name).
    if ($null -ne (Get-ChildItem -Path $AttachmentFolder\* -Include *.xml)) {
        Write-Host "Moving decrypted XML files to staging folders..." -ForegroundColor Cyan
        Write-Host "    Letting filesystem catch up..."
        Start-Sleep 5

        try {
            # Remove any trailing slashes.
            if ($StagingFolder[-1] -eq "\") {
                $StagingFolder = $StagingFolder.Substring(1,$StagingFolder.Length - 2)
            }
            Set-Location $AttachmentFolder
            Write-Host "    Moving deprecated_Backup files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*deprecated_Backup*.xml" } | Move-Item -Destination "$StagingFolder\Backup" -Force
            Write-Host "    Moving deprecated_Databases files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*deprecated_Databases*.xml" } | Move-Item -Destination "$StagingFolder\Databases" -Force
            Write-Host "    Moving deprecated_ErrorLog files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*deprecated_ErrorLog*.xml" } | Move-Item -Destination "$StagingFolder\ErrorLog" -Force
            Write-Host "    Moving deprecated_Job files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*deprecated_Job*.xml" } | Move-Item -Destination "$StagingFolder\Job" -Force
            Write-Host "    Moving deprecated_Version files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*deprecated_Version*.xml" } | Move-Item -Destination "$StagingFolder\Version" -Force
            Write-Host "    Moving deprecated_log_Job files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_Job*.xml" } | Move-Item -Destination "$StagingFolder\log_Job" -Force
            Write-Host "    Moving deprecated_log_audit files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_audit*.xml" } | Move-Item -Destination "$StagingFolder\log_audit" -Force
            Write-Host "    Moving deprecated_log_Backup files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_Backup*.xml" } | Move-Item -Destination "$StagingFolder\log_Backup" -Force
            Write-Host "    Moving deprecated_log_Error files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_Error*.xml" } | Move-Item -Destination "$StagingFolder\log_Error" -Force
            Write-Host "    Moving deprecated_log_maintenance files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_maintenance*.xml" } | Move-Item -Destination "$StagingFolder\log_maintenance" -Force
            Write-Host "    Moving deprecated_log_capacity_drive_usage files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_capacity_drive_usage*.xml" } | Move-Item -Destination "$StagingFolder\log_capacity_drive_usage" -Force
            Write-Host "    Moving deprecated_log_capacity_filegroup files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*log_capacity_filegroup*.xml" } | Move-Item -Destination "$StagingFolder\log_capacity_filegroup" -Force
            Write-Host "    Moving deprecated_log_capacity files to staging folder..."
            Get-ChildItem | Where-Object { $_.Name -like "*`[log_capacity`]*.xml" } | Move-Item -Destination "$StagingFolder\log_capacity" -Force
        }
        catch {
            Write-Host "Error moving decrypted XML files: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "No decrypted XML files to move!" -ForegroundColor Cyan
    }

    ## Remove old log files
    try
    {
        $date = Get-Date

        Get-ChildItem $ExtractorDirectory -Recurse -Include *dbaid_extractor_*.log | Where-Object {($_.LastWriteTime -le $date.AddDays($MaxAge))} | Remove-Item -Force
    }
    catch
    {
      Write-Host "Error deleting old log files from ${ExtractorDirectory}: $_" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error encountered: $_" -ForegroundColor Red
}
finally {
    <#  Clean up the variables rather than waiting for .NET garbage collector.  #>
    If (Test-Path variable:local:MailboxAddress) { Remove-Variable MailboxAddress }
    If (Test-Path variable:local:MailboxSubjectFilter) { Remove-Variable MailboxSubjectFilter }
    If (Test-Path variable:local:AttachmentRootFolder) { Remove-Variable AttachmentRootFolder }
    If (Test-Path variable:local:AttachmentFolder) { Remove-Variable AttachmentFolder }
    If (Test-Path variable:local:StagingRootFolder) { Remove-Variable StagingRootFolder }
    If (Test-Path variable:local:StagingFolder) { Remove-Variable StagingFolder }
    If (Test-Path variable:local:ExtractorDirectory) { Remove-Variable ExtractorDirectory }
    If (Test-Path variable:local:LogFilePath) { Remove-Variable LogFilePath }
    If (Test-Path variable:local:MaxAge) { Remove-Variable MaxAge }
    If (Test-Path variable:local:TenantID) { Remove-Variable TenantID }
    If (Test-Path variable:local:Credentials) { Remove-Variable Credentials }
    If (Test-Path variable:local:AppID) { Remove-Variable AppID }
    If (Test-Path variable:local:ClientSecret) { Remove-Variable ClientSecret }
    If (Test-Path variable:local:EWSScope) { Remove-Variable EWSScope }
    If (Test-Path variable:local:RequestBody) { Remove-Variable RequestBody }
    If (Test-Path variable:local:OAuthResponse) { Remove-Variable OAuthResponse }
    If (Test-Path variable:local:AccessToken) { Remove-Variable AccessToken }
    If (Test-Path variable:local:EWSClient) { Remove-Variable EWSClient }
    If (Test-Path variable:local:SrchFltrIsRead) { Remove-Variable SrchFltrIsRead }
    If (Test-Path variable:local:SrchFltrSubj) { Remove-Variable SrchFltrSubj }
    If (Test-Path variable:local:SrchFltrCollection) { Remove-Variable SrchFltrCollection }
    If (Test-Path variable:local:MailItemsToProcess) { Remove-Variable MailItemsToProcess }
    If (Test-Path variable:local:ColHeaders) { Remove-Variable ColHeaders }
    If (Test-Path variable:local:AttachmentCounter) { Remove-Variable AttachmentCounter }
    If (Test-Path variable:local:From) { Remove-Variable From }
    If (Test-Path variable:local:Subject) { Remove-Variable Subject }
    If (Test-Path variable:local:AttachmentSavedSuccessful) { Remove-Variable AttachmentSavedSuccessful }
    If (Test-Path variable:local:AttachmentNotSavedSuccessful) { Remove-Variable AttachmentNotSavedSuccessful }
    If (Test-Path variable:local:InboxSubFolders) { Remove-Variable InboxSubFolders }
    If (Test-Path variable:local:SaveErrorFileCollection) { Remove-Variable SaveErrorFileCollection }
    If (Test-Path variable:local:AttachName) { Remove-Variable AttachName }
    If (Test-Path variable:local:SavePathAndFileName) { Remove-Variable SavePathAndFileName }
    If (Test-Path variable:local:File) { Remove-Variable File }
    If (Test-Path variable:local:SaveError) { Remove-Variable SaveError }
    If (Test-Path variable:local:TargetFolderID) { Remove-Variable TargetFolderID }
    If (Test-Path variable:local:Comment) { Remove-Variable Comment }
    If (Test-Path variable:local:DT) { Remove-Variable DT }
    If (Test-Path variable:local:date) { Remove-Variable date }

    Write-Host "DBAid extraction process complete." -ForegroundColor Magenta
    Stop-Transcript | Out-Null
}