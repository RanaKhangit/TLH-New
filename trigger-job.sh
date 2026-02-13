#!/bin/bash

# Chainlink Node credentials — set these env vars before running
: "${CHAINLINK_EMAIL:?ERROR: CHAINLINK_EMAIL is not set}"
: "${CHAINLINK_PASSWORD:?ERROR: CHAINLINK_PASSWORD is not set}"

# Login to get session cookie
echo "Logging in to Chainlink node..."
curl -s -X POST http://localhost:6688/sessions \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${CHAINLINK_EMAIL}\",\"password\":\"${CHAINLINK_PASSWORD}\"}" \
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
