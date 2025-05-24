# =====================================
# Azure Blob Upload Script - Client Version
# =====================================

# Prompt for local folder path (containing CSV files)
$LOCAL_FOLDER_PATH = Read-Host -Prompt "📁 Enter the full path to your local folder with CSV files"

# Validate folder
if (-not (Test-Path -Path $LOCAL_FOLDER_PATH)) {
    Write-Host "❌ ERROR: Folder not found. Please check the path and try again." -ForegroundColor Red
    exit 1
}

# Azure Storage Account container name
$CONTAINER_NAME = "bronze"

# Base URL to your container (without SAS token)
$BASE_SAS_URL = "https://dlbilbodataflowdev.blob.core.windows.net/$CONTAINER_NAME"

# Prompt for SAS token (everything after '?')
if (-not $env:SAS_TOKEN) {
    $SAS_TOKEN = Read-Host -Prompt "🔐 Enter your SAS token (everything after the '?')"
}
else {
    $SAS_TOKEN = $env:SAS_TOKEN
}

# Get all CSV files in the local folder
$files = Get-ChildItem -Path $LOCAL_FOLDER_PATH -Filter "*.csv"

if ($files.Count -eq 0) {
    Write-Host "⚠️ No CSV files found in the folder." -ForegroundColor Yellow
    exit 0
}

# Get current UTC date
$now = Get-Date -AsUTC
$folderPath = $now.ToString("yyyy/MM/dd")
$timestamp = $now.ToString("yyyy-MM-ddTHH-mm-ss")

foreach ($file in $files) {
    $filePath = $file.FullName
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $extension = [System.IO.Path]::GetExtension($file.Name)

    $newFileName = "$baseName" + "_$timestamp" + "$extension"
    $remoteBlobPath = "winassist/$folderPath/$newFileName"
    $BLOB_SAS_URL = "$BASE_SAS_URL/$remoteBlobPath`?$SAS_TOKEN"

    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)

    $uploadHeaders = @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/octet-stream"
    }

    Write-Host "`n📤 Uploading: $newFileName to winassist/$folderPath/"
    try {
        Invoke-RestMethod -Uri $BLOB_SAS_URL -Method Put -Body $fileBytes -Headers $uploadHeaders
        Write-Host "✅ Uploaded successfully: $newFileName"
    }
    catch {
        Write-Host "❌ Upload failed for $newFileName. Error: $_"
        continue
    }

    # Verify the blob exists
    try {
        $verifyHeaders = @{ "x-ms-version" = "2022-11-02" }
        $verify = Invoke-WebRequest -Uri $BLOB_SAS_URL -Method Head -Headers $verifyHeaders
        if ($verify.StatusCode -eq 200) {
            Write-Host "🔍 Verified: $newFileName exists in Azure Blob Storage."
        }
        else {
            Write-Host "⚠️ Verification failed: HTTP $($verify.StatusCode)"
        }
    }
    catch {
        Write-Host "❌ Could not verify upload for $newFileName. Error: $_"
    }
}
