Import-Module ActiveDirectory

# ==============================
# Configuration
# ==============================
$CsvPath = "C:\Scripts\NewUsersSent.csv"
$LogPath = "C:\Scripts\AD_User_Creation.log"

# Mandatory fields (cannot be empty)
$MandatoryFields = @(
    "firstname",
    "lastname",
    "username",
    "password",
    "OU",
    "Email"
)

# Start logging
Start-Transcript -Path $LogPath -Append

# Import CSV
$ADUsers = Import-Csv -Path $CsvPath

foreach ($User in $ADUsers) {

    Write-Host "Processing user: $($User.username)" -ForegroundColor Cyan

    # ==============================
    # Validate mandatory fields
    # ==============================
    $MissingFields = @()

    foreach ($Field in $MandatoryFields) {
        if ([string]::IsNullOrWhiteSpace($User.$Field)) {
            $MissingFields += $Field
        }
    }

    if ($MissingFields.Count -gt 0) {
        Write-Warning "Skipping user [$($User.username)] - Missing mandatory fields: $($MissingFields -join ', ')"
        continue
    }

    # ==============================
    # Check if user exists
    # ==============================
    if (Get-ADUser -Filter "SamAccountName -eq '$($User.username)'" -ErrorAction SilentlyContinue) {
        Write-Warning "User $($User.username) already exists. Skipping creation."
        continue
    }

    # ==============================
    # Create AD User
    # ==============================
    try {
        New-ADUser `
            -SamAccountName $User.username `
            -UserPrincipalName "$($User.username)@jmbaxigrp.com" `
            -Name "$($User.firstname) $($User.lastname)" `
            -GivenName $User.firstname `
            -Surname $User.lastname `
            -DisplayName "$($User.lastname) $($User.firstname)" `
            -Path $User.OU `
            -City $User.City `
            -Company $User.Company `
            -Title $User.jobtitle `
            -Department $User.department `
            -Office $User.office `
            -State $User.State `
            -EmailAddress $User.Email `
            -Description $User.Description `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -AccountPassword (ConvertTo-SecureString $User.password -AsPlainText -Force)

        Write-Host "User $($User.username) created successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create user $($User.username): $_"
        continue
    }

    # ==============================
    # Group Assignment
    # ==============================
    if (-not [string]::IsNullOrWhiteSpace($User.Groups)) {

        $Groups = $User.Groups -split ";"

        foreach ($Group in $Groups) {
            try {
                Add-ADGroupMember -Identity $Group.Trim() -Members $User.username
                Write-Host "Added $($User.username) to group $Group" -ForegroundColor Yellow
            }
            catch {
                Write-Warning "Failed to add $($User.username) to group $Group : $_"
            }
        }
    }
    else {
        Write-Warning "No groups specified for user $($User.username)"
    }
}

Stop-Transcript
Read-Host "Press Enter to exit"
