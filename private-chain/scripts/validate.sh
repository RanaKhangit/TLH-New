#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# TLH Private Trust Chain — Validation Script
# Verifies: chain ID, block production, deployed contracts, and roles.
#
# Prerequisites:
#   - Polygon Edge network running
#   - Contracts deployed (deploy-trust-contracts.sh)
#
# Usage: ./scripts/validate.sh
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
EXPECTED_CHAIN_ID="${CHAIN_ID:-100100}"

PASS=0
FAIL=0
CHECKS=()

pass() {
    PASS=$((PASS + 1))
    CHECKS+=("[PASS] $1")
    echo "  [PASS] $1"
}

fail() {
    FAIL=$((FAIL + 1))
    CHECKS+=("[FAIL] $1")
    echo "  [FAIL] $1"
}

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  TLH Private Trust Chain — Validation                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Check 1: Chain reachable ────────────────────────────────────────
echo "[1/6] Chain connectivity..."
CHAIN_ID_HEX=$(cast rpc eth_chainId --rpc-url "$RPC_URL" 2>/dev/null || echo "UNREACHABLE")
if [ "$CHAIN_ID_HEX" = "UNREACHABLE" ]; then
    fail "Chain not reachable at $RPC_URL"
else
    pass "Chain reachable at $RPC_URL"
fi

# ── Check 2: Chain ID ──────────────────────────────────────────────
echo "[2/6] Chain ID..."
ACTUAL_CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
if [ "$ACTUAL_CHAIN_ID" = "$EXPECTED_CHAIN_ID" ]; then
    pass "Chain ID = $ACTUAL_CHAIN_ID (expected $EXPECTED_CHAIN_ID)"
else
    fail "Chain ID = $ACTUAL_CHAIN_ID (expected $EXPECTED_CHAIN_ID)"
fi

# ── Check 3: Block production ─────────────────────────────────────
echo "[3/6] Block production..."
BLOCK_1=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
sleep 3
BLOCK_2=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
if [ "$BLOCK_2" -gt "$BLOCK_1" ]; then
    pass "Blocks advancing: $BLOCK_1 -> $BLOCK_2"
else
    fail "Blocks not advancing: $BLOCK_1 -> $BLOCK_2"
fi

# ── Check 4: Deployment manifest exists ────────────────────────────
echo "[4/6] Deployment manifest..."
if [ -f "$MANIFEST" ]; then
    pass "Manifest found: $MANIFEST"

    # Extract addresses from manifest
    CRED_PROXY=$(python3 -c "import json; m=json.load(open('$MANIFEST')); print(m['contracts']['CredentialRegistry']['proxy'])" 2>/dev/null || echo "")
    TAV_PROXY=$(python3 -c "import json; m=json.load(open('$MANIFEST')); print(m['contracts']['TrustAttestationVerifier']['proxy'])" 2>/dev/null || echo "")
else
    fail "Manifest not found: $MANIFEST"
    CRED_PROXY=""
    TAV_PROXY=""
fi

# ── Check 5: Contracts deployed ───────────────────────────────────
echo "[5/6] Contract bytecode..."
if [ -n "$CRED_PROXY" ]; then
    CRED_CODE=$(cast code "$CRED_PROXY" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    if [ "$CRED_CODE" != "0x" ] && [ ${#CRED_CODE} -gt 4 ]; then
        pass "CredentialRegistry proxy has bytecode at $CRED_PROXY"
    else
        fail "CredentialRegistry proxy has no bytecode at $CRED_PROXY"
    fi
else
    fail "CredentialRegistry proxy address not available"
fi

if [ -n "$TAV_PROXY" ]; then
    TAV_CODE=$(cast code "$TAV_PROXY" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    if [ "$TAV_CODE" != "0x" ] && [ ${#TAV_CODE} -gt 4 ]; then
        pass "TrustAttestationVerifier proxy has bytecode at $TAV_PROXY"
    else
        fail "TrustAttestationVerifier proxy has no bytecode at $TAV_PROXY"
    fi
else
    fail "TrustAttestationVerifier proxy address not available"
fi

# ── Check 6: Role wiring ─────────────────────────────────────────
echo "[6/6] Role wiring..."
if [ -n "$CRED_PROXY" ] && [ -n "$TAV_PROXY" ]; then
    # VERIFIER_ROLE = keccak256("VERIFIER_ROLE")
    VERIFIER_ROLE=$(cast keccak "VERIFIER_ROLE" 2>/dev/null || echo "")

    if [ -n "$VERIFIER_ROLE" ]; then
        HAS_ROLE=$(cast call "$CRED_PROXY" "hasRole(bytes32,address)(bool)" "$VERIFIER_ROLE" "$TAV_PROXY" --rpc-url "$RPC_URL" 2>/dev/null || echo "false")
        if [ "$HAS_ROLE" = "true" ]; then
            pass "TrustAttestationVerifier has VERIFIER_ROLE on CredentialRegistry"
        else
            fail "TrustAttestationVerifier missing VERIFIER_ROLE on CredentialRegistry"
        fi
    else
        fail "Could not compute VERIFIER_ROLE hash"
    fi
else
    fail "Cannot check roles: contract addresses not available"
fi

# ── Summary ───────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Validation Results"
echo "───────────────────────────────────────────────────────────"
for check in "${CHECKS[@]}"; do
    echo "  $check"
done
echo "───────────────────────────────────────────────────────────"
echo "  Total: $((PASS + FAIL))  |  Pass: $PASS  |  Fail: $FAIL"
echo "═══════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
