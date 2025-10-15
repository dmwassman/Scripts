<#
.SYNOPSIS 
    M365 MFA Report

.DESCRIPTION 
    Generates and emails a report of Microsoft 365 users who have Self-Service Password Reset (SSPR) enabled 
    but have not registered Multi-Factor Authentication (MFA). 
    The report is emailed to a specified recipient and old reports (older than 30 days) are purged automatically.

.NOTES 
    Requirements:
        Microsoft Graph PowerShell SDK
    File Name: 
        mfaReport.ps1
    Author: 
        David Wassman
    Date:
        October 13, 2025

.OUTPUTS 
    M365MFAChallengedUsers report (Deletes after 30 days)
#>

[CmdletBinding()]
Param 
(
    [Parameter(Mandatory=$false, HelpMessage="Enter an email address to send the report to", Position=0, ValueFromPipeline=$false)]
    [ValidateScript({
        try {
            $null = [mailaddress]$_
            $true
        } catch {
            throw [System.Management.Automation.ValidationMetadataException] "Invalid input detected. Please enter a valid email address."
        }
    })]
    [string]$Email = "helpdesk@ocpmgmt.com",
    [Parameter(Mandatory=$false, HelpMessage="Only output the count of users without MFA")]
    [switch]$Count,
    [Parameter(Mandatory=$false, HelpMessage="Only output the list of users without MFA")]
    [switch]$List
)

# --- Configuration Variables ---
$tenantId        = "50e974dd-1d82-4344-88dd-8b8b5cad9e11"   # Azure AD tenant ID
$applicationId   = "62df369a-4d18-4ce8-a0ad-8abad25ebe3e"   # App registration (client ID)
$certThumbprint  = "967066E22D1E780AD93E2D64300E94067CC85254" # Certificate thumbprint for Graph auth
$reportPath      = "C:\IT"                                  # Local report folder
$retentionDays   = 30                                       # Days to keep reports
$sender          = "helpdesk@ocpmgmt.com"                   # From address


if($Count -and $List){
    throw "Count and List cannot be used together."
}

# --- Load authentication certificate ---
try {
    $cert = Get-ChildItem "Cert:\CurrentUser\My\$certThumbprint" -ErrorAction Stop
    if (-not $cert) { 
        $cert = Get-ChildItem "Cert:\LocalMachine\My\$certThumbprint" -ErrorAction Stop
        if(-not $cert){
            throw "Certificate with thumbprint $certThumbprint not found." 
        }
    }
    Write-Host "Certificate loaded successfully."
} catch {
    throw "ERROR: Unable to retrieve authentication certificate. $_"
}

# --- Connect to Microsoft Graph using App-Only Authentication ---
try {
    Connect-MgGraph -TenantId $tenantId -ClientId $applicationId -Certificate $cert -NoWelcome -ErrorAction Stop
    Write-Host "Connected to Microsoft Graph successfully."
} catch {
    throw "ERROR: Failed to connect to Microsoft Graph. $_"
}

# --- Retrieve users without MFA but with SSPR enabled ---
try {
    Write-Host "Fetching user registration details from Microsoft Graph..."
    $Users = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop | Where-Object {
        $_.IsSsprEnabled -and -not $_.IsMfaCapable -and $_.UserDisplayName -ne "On-Premises Directory Synchronization Service Account"
    } | Sort-Object -Property userPrincipalName
} catch {
    throw "ERROR: Failed to retrieve user registration details from Graph. $_"
}

if($Count){
    Write-Host "Number of users without MFA: $($users.Count)"
} elseif($List) {
    $Users | Select-Object UserDisplayName, UserPrincipalName | Format-Table -AutoSize
}else{

    # --- Ensure report directory exists ---
    if (!(Test-Path -Path $reportPath)) {
        try {
            New-Item -ItemType Directory -Path $reportPath -ErrorAction Stop | Out-Null
            Write-Host "Created directory: $reportPath"
        } catch {
            throw "ERROR: Unable to create report directory at '$reportPath'. $_"
        }
    }

    # --- Prepare report file path ---
    $fileName = "M365MFAChallengedUsers_$(Get-Date -Format 'yyyy.MM.dd.HH.mm.ss').csv"
    $filePath = Join-Path $reportPath $fileName

    # Initialize CSV header
    try {
        "User,Email" | Set-Content -Path $filePath -ErrorAction Stop
        Write-Host "Initialized report file: $filePath"
    } catch {
        throw "ERROR: Unable to initialize report file. $_"
    }



    # --- Write report data ---
    try {
        foreach ($user in $Users) {
            "$($user.userDisplayName.Replace(',','')),$($user.userPrincipalName)" | Add-Content -Path $filePath -ErrorAction Stop
        }
        Write-Host "Report successfully written with $($Users.Count) entries."
    } catch {
        throw "ERROR: Failed while writing user data to report file. $_"
    }

# --- Prepare email body and attachment ---
    try {
        Add-Type -AssemblyName System.Web
        $contentType       = [System.Web.MimeMapping]::GetMimeMapping($fileName)
        $attachmentContent = [Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath))
        $subject           = "M365 Users Without MFA - $(Get-Date -Format F)"
        $body              = @"
IT Support,<br><br>
Attached is a list of users that have <b>NOT</b> registered MFA in M365.<br><br>
Please reach out to them and assist them in setting up their MFA.<br><br>
-- Automated System Report
"@
    } catch {
        throw "ERROR: Failed while preparing email content or attachment. $_"
    }

    # --- Construct email message payload ---
    $emailParams = @{
        message = @{
            subject = $subject
            body = @{
                contentType = "HTML"
                content = $body
            }
            toRecipients = @(
                @{
                    emailAddress = @{ address = $Email }
                }
            )
            attachments = @(
                @{
                    "@odata.type" = "#microsoft.graph.fileAttachment"
                    name = $fileName
                    contentType = $contentType
                    contentBytes = $attachmentContent
                }
            )
        }
        saveToSentItems = $false
    }

    # --- Attempt to send the email ---
    try {
        Send-MgUserMail -UserId $sender -BodyParameter $emailParams -ErrorAction Stop
        Write-Host "Report email sent successfully to $Email"
    } catch {
        throw "ERROR: Failed to send report email. $_"
    }

    # --- Cleanup old reports (older than $retentionDays) ---
    try {
        $limit = (Get-Date).AddDays(-$retentionDays)
        Get-ChildItem -Path $reportPath -Filter 'M365MFAChallengedUsers_*.csv' -ErrorAction Stop | 
            Where-Object { $_.CreationTime -lt $limit } | 
            Remove-Item -Force -ErrorAction Stop
        Write-Host "Old reports older than $retentionDays days have been cleaned up."
    } catch {
        Write-Warning "WARNING: Unable to clean up old reports. $_"
    }
}

 Disconnect-MgGraph | Out-Null
Write-Host "MFA report script completed successfully."
