param (
    [string]$sourceRepo,  # Source repository in 'owner/repo' format
    [string]$targetRepo   # Target repository in 'owner/repo' format
)

# Extract owner and repo names from the parameters
$sourceRepoOwner, $sourceRepoName = $sourceRepo -split "/"
$targetRepoOwner, $targetRepoName = $targetRepo -split "/"

# Retrieve the PAT tokens from environment variables
$sourceToken = $env:SOURCE_PAT
$targetToken = $env:TARGET_PAT

# Ensure both tokens are present
if (-not $sourceToken) {
    Write-Host "Source PAT token is missing!" -ForegroundColor Red
    exit 1
}

if (-not $targetToken) {
    Write-Host "Target PAT token is missing!" -ForegroundColor Red
    exit 1
}

# Function to get secret scanning alerts from a repository
function Get-SecretScanningAlerts($token, $repoOwner, $repoName) {
    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github.v3+json"
    }

    $url = "https://api.github.com/repos/$repoOwner/$repoName/secret-scanning/alerts"
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        return $response
    } catch {
        Write-Host "Error fetching secret scanning alerts: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to update secret scanning alerts in the target repository
function Update-SecretScanningAlert($token, $repoOwner, $repoName, $alertNumber, $newState) {
    $headers = @{
        Authorization = "token $token"
        Accept        = "application/vnd.github.v3+json"
    }

    $body = @{
        state = $newState
    } | ConvertTo-Json

    $url = "https://api.github.com/repos/$repoOwner/$repoName/secret-scanning/alerts/$alertNumber"

    try {
        Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body
        Write-Host "Alert #$alertNumber updated to state '$newState'." -ForegroundColor Green
    } catch {
        Write-Host "Error updating alert #$alertNumber: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to handle the migration of secret scanning remediation states
function Migrate-SecretScanningRemediationStates {
    param (
        [string]$sourceToken,
        [string]$targetToken,
        [string]$sourceRepoOwner,
        [string]$sourceRepoName,
        [string]$targetRepoOwner,
        [string]$targetRepoName
    )

    # Get secret scanning alerts from the source repository
    Write-Host "Fetching secret scanning alerts from source repository ($sourceRepoOwner/$sourceRepoName)..."
    $sourceAlerts = Get-SecretScanningAlerts -token $sourceToken -repoOwner $sourceRepoOwner -repoName $sourceRepoName

    if ($sourceAlerts -eq $null -or $sourceAlerts.Count -eq 0) {
        Write-Host "No secret scanning alerts found in the source repository. Nothing to migrate." -ForegroundColor Yellow
        return
    }

    Write-Host "$($sourceAlerts.Count) secret scanning alert(s) found in the source repository."

    # Loop through each alert and update the target repository with the same remediation state
    foreach ($alert in $sourceAlerts) {
        $alertNumber = $alert.number
        $alertState = $alert.state

        Write-Host "Migrating secret alert #$alertNumber with state '$alertState'..."

        # Update the alert in the target repository with the same state
        Update-SecretScanningAlert -token $targetToken -repoOwner $targetRepoOwner -repoName $targetRepoName -alertNumber $alertNumber -newState $alertState
    }

    Write-Host "Secret scanning remediation states migrated successfully." -ForegroundColor Green
}

# Print inputs for logging
Write-Host "Source Organization: $sourceRepoOwner"
Write-Host "Source Repository: $sourceRepoName"
Write-Host "Target Organization: $targetRepoOwner"
Write-Host "Target Repository: $targetRepoName"

# Call the migration function
Migrate-SecretScanningRemediationStates -sourceToken $sourceToken -targetToken $targetToken -sourceRepoOwner $sourceRepoOwner -sourceRepoName $sourceRepoName -targetRepoOwner $targetRepoOwner -targetRepoName $targetRepoName
