#!/bin/bash

# === CONFIGURATION ===
STORAGE_ACCOUNT_NAME="dlbilbodataflowprod"
CONTAINER_NAME="bronze"
POLICY_NAME="gds-write-policy"

# Generate current UTC start time
START_DATE=$(date -u +"%Y-%m-%dT%H:%MZ")

# macOS-compatible: Add 10 years
EXPIRY_DATE=$(date -u -v+10y +"%Y-%m-%dT%H:%MZ")

# Full write access: Read, List, Add, Create, Write
PERMISSIONS="rlacw"

echo "⏳ Creating stored access policy '$POLICY_NAME' valid from $START_DATE to $EXPIRY_DATE with permissions $PERMISSIONS..."

az storage container policy create \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --container-name "$CONTAINER_NAME" \
  --name "$POLICY_NAME" \
  --start "$START_DATE" \
  --expiry "$EXPIRY_DATE" \
  --permissions "$PERMISSIONS"

echo "✅ Stored access policy created."

echo "🔐 Generating SAS token using policy '$POLICY_NAME'..."

SAS_TOKEN=$(az storage container generate-sas \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --name "$CONTAINER_NAME" \
  --policy-name "$POLICY_NAME" \
  --output tsv)

SAS_URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${CONTAINER_NAME}?${SAS_TOKEN}"

echo ""
echo "🔗 SAS URL (Write + Read access, use with gds/YYYY/MM/DD/filename.csv):"
echo "$SAS_URL"
