#!/bin/bash

# Check if both client_id and secret are passed as arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <client_id> <secret>"
  exit 1
fi

# Assign client_id and secret from command line arguments
client_id=$1
secret=$2

# Step 1: Create a Sandbox Public Token
echo "Creating sandbox public token..."
public_token=$(curl -s -X POST https://sandbox.plaid.com/sandbox/public_token/create \
-H "Content-Type: application/json" \
-d '{
      "institution_id": "ins_109508",
      "initial_products": ["assets"],
      "client_id": "'"$client_id"'",
      "secret": "'"$secret"'"
    }' | jp -u 'public_token')

# Check if public_token is retrieved
if [ -z "$public_token" ]; then
  echo "Failed to retrieve public_token."
  exit 1
fi

echo "Public token created: $public_token"

# Step 2: Exchange Public Token for Access Token
echo "Exchanging public token for access token..."
access_token=$(curl -s -X POST https://sandbox.plaid.com/item/public_token/exchange \
-H "Content-Type: application/json" \
-d '{
      "public_token": "'"$public_token"'",
      "client_id": "'"$client_id"'",
      "secret": "'"$secret"'"
    }' | jp -u 'access_token')

# Check if access_token is retrieved
if [ -z "$access_token" ] || [ "$access_token" = "null" ]; then
  echo "Failed to retrieve access_token."
  exit 1
fi

echo "Access token received: $access_token"

# Step 3: Create Asset Report
echo "Creating asset report..."
asset_report_token=$(curl -s -X POST https://sandbox.plaid.com/asset_report/create \
-H "Content-Type: application/json" \
-d '{
      "access_tokens": ["'"$access_token"'"],
      "days_requested": 30,
      "client_id": "'"$client_id"'",
      "secret": "'"$secret"'"
    }' | jp -u 'asset_report_token')

# Check if asset_report_token is retrieved
if [ -z "$asset_report_token" ] || [ "$asset_report_token" = "null" ]; then
  echo "Failed to retrieve asset_report_token."
  exit 1
fi

# Step 4: Print asset_report_token
echo ""
echo "=========================================="
echo "Asset report token: $asset_report_token"
echo "=========================================="
