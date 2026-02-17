#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# TLH Private Trust Chain — Contract Deployment Script
# Deploys CredentialRegistry + TrustAttestationVerifier to Polygon Edge.
#
# Prerequisites:
#   - Polygon Edge network running (docker compose up)
#   - Foundry installed (forge)
#   - .env file configured (copy from .env.example)
#
# Usage: ./scripts/deploy-trust-contracts.sh
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRACTS_DIR="$(cd "$ROOT_DIR/../contracts" && pwd)"
MANIFEST="$CONTRACTS_DIR/deployment-manifest.private-chain.json"

# Load environment
if [ -f "$ROOT_DIR/.env" ]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

RPC_URL="${RPC_URL:-http://localhost:8545}"
CHAIN_ID="${CHAIN_ID:-100100}"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  TLH Private Trust Chain — Contract Deployment          ║"
echo "║  RPC:      $RPC_URL"
echo "║  Chain ID: $CHAIN_ID"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Pre-flight checks ──────────────────────────────────────────────
echo "[1/4] Pre-flight checks..."

# Verify chain is reachable
REPORTED_CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "UNREACHABLE")
if [ "$REPORTED_CHAIN_ID" = "UNREACHABLE" ]; then
    echo "  ERROR: Cannot reach RPC at $RPC_URL"
    echo "  Is the Polygon Edge network running? (docker compose up -d)"
    exit 1
fi

if [ "$REPORTED_CHAIN_ID" != "$CHAIN_ID" ]; then
    echo "  ERROR: Chain ID mismatch. Expected $CHAIN_ID, got $REPORTED_CHAIN_ID"
    exit 1
fi
echo "  Chain ID verified: $REPORTED_CHAIN_ID"

# Verify deployer has funds
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PRIVATE_KEY" 2>/dev/null || echo "")
if [ -z "$DEPLOYER_ADDR" ]; then
    echo "  ERROR: Invalid DEPLOYER_PRIVATE_KEY"
    exit 1
fi
BALANCE=$(cast balance "$DEPLOYER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
echo "  Deployer: $DEPLOYER_ADDR"
echo "  Balance:  $BALANCE wei"

# ── Compile contracts ──────────────────────────────────────────────
echo ""
echo "[2/4] Compiling contracts..."
cd "$CONTRACTS_DIR"
forge build --silent

# ── Deploy ─────────────────────────────────────────────────────────
echo ""
echo "[3/4] Deploying trust contracts..."

OUTPUT=$(forge script script/DeployPrivateChain.s.sol:DeployPrivateChain \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --legacy \
    -vvv 2>&1)

echo "$OUTPUT"

# ── Generate manifest ─────────────────────────────────────────────
echo ""
echo "[4/4] Generating deployment manifest..."

# Extract addresses from forge output
CRED_IMPL=$(echo "$OUTPUT" | grep "CredentialRegistry impl:" | awk '{print $NF}')
CRED_PROXY=$(echo "$OUTPUT" | grep "CredentialRegistry proxy:" | awk '{print $NF}')
TAV_IMPL=$(echo "$OUTPUT" | grep "TrustAttestationVerifier impl:" | awk '{print $NF}')
TAV_PROXY=$(echo "$OUTPUT" | grep "TrustAttestationVerifier proxy:" | awk '{print $NF}')

if [ -z "$CRED_IMPL" ] || [ -z "$CRED_PROXY" ] || [ -z "$TAV_IMPL" ] || [ -z "$TAV_PROXY" ]; then
    echo "  WARNING: Could not extract all addresses from forge output."
    echo "  Check broadcast/ for deployment details."
    exit 1
fi

cat > "$MANIFEST" <<EOF
{
  "chainId": $CHAIN_ID,
  "network": "private-chain",
  "deployer": "$DEPLOYER_ADDR",
  "admin": "$ADMIN_ADDRESS",
  "artifacts": {
    "broadcastFile": "broadcast/DeployPrivateChain.s.sol/$CHAIN_ID/run-latest.json"
  },
  "contracts": {
    "CredentialRegistry": {
      "implementation": "$CRED_IMPL",
      "proxy": "$CRED_PROXY"
    },
    "TrustAttestationVerifier": {
      "implementation": "$TAV_IMPL",
      "proxy": "$TAV_PROXY"
    }
  }
}
EOF

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Deployment complete!"
echo "  Manifest: $MANIFEST"
echo ""
echo "  CredentialRegistry proxy:          $CRED_PROXY"
echo "  TrustAttestationVerifier proxy:    $TAV_PROXY"
echo ""
echo "  Next: ./scripts/validate.sh"
echo "═══════════════════════════════════════════════════════════"
