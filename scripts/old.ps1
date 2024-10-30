# Set up source and target repository details
$SOURCE_REPO = "saideep11111/source2"
$TARGET_REPO = "source11112/source2"
$TARGET_REF = "refs/heads/main"
$GITHUB_TOKEN = "your_token_here"

# Retrieve the latest commit SHA for the target branch in the target repository
Write-Output "Retrieving the latest commit SHA for the target repository..."
$TARGET_COMMIT_SHA = gh api -X GET "/repos/$TARGET_REPO/commits/main" --jq '.sha' 2>&1

# Ensure the commit SHA was retrieved
if ($TARGET_COMMIT_SHA -match "Not Found") {
    Write-Output "Failed to retrieve the latest commit SHA for the target repository."
    exit 1
}

Write-Output "Using commit SHA: $TARGET_COMMIT_SHA"

# Process each analysis
$analysis_ids = gh api -X GET "/repos/$SOURCE_REPO/code-scanning/analyses" --jq '.[].id'

foreach ($analysis_id in $analysis_ids) {
    Write-Output "Processing analysis ID: $analysis_id from source repository..."

    $sarif_content = gh api -X GET "/repos/$SOURCE_REPO/code-scanning/analyses/$analysis_id" --jq '.sarif' | Out-String | % { [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_)) }

    if ([string]::IsNullOrEmpty($sarif_content)) {
        Write-Output "No SARIF data found for analysis ID: $analysis_id. Skipping."
        continue
    }

    Write-Output "Uploading SARIF for analysis ID: $analysis_id to the target repository..."
    gh api -X POST `
        -H "Authorization: token $GITHUB_TOKEN" `
        -H "Accept: application/vnd.github+json" `
        repos/$TARGET_REPO/code-scanning/sarifs `
        -F "commit_sha=$TARGET_COMMIT_SHA" `
        -F "ref=$TARGET_REF" `
        -F "sarif=$sarif_content"
}
