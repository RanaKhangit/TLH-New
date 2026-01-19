#!/bin/bash

# Login to get session cookie
echo "Logging in to Chainlink node..."
curl -s -X POST http://localhost:6688/sessions \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@pixelette.local","password":"PixeletteChainlink2024!"}' \
  -c /tmp/chainlink-cookies.txt > /dev/null

# Trigger the webhook job
echo "Triggering DECO verification job..."
RESULT=$(curl -s -X POST "http://localhost:6688/v2/jobs/a1b2c3d4-e5f6-7890-abcd-ef1234567890/runs" \
  -H "Content-Type: application/json" \
  -b /tmp/chainlink-cookies.txt \
  -d '{}')

# Check if jq is available
if command -v jq &> /dev/null; then
  echo ""
  echo "=== Job Run Result ==="
  echo "$RESULT" | jq '.data.attributes | {errors: .errors, taskRuns: [.taskRuns[] | {type, error, output}]}'
else
  echo "$RESULT"
fi
