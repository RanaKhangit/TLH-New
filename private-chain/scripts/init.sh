#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────
# TLH Private Trust Chain — Initialisation Script
# Generates 4 validator secrets and the IBFT 2.0 genesis file.
#
# Prerequisites: Docker installed and running.
# Usage:         ./scripts/init.sh
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$ROOT_DIR/data"
IMAGE="0xpolygon/polygon-edge:0.9.0"

# ── Configuration ───────────────────────────────────────────────────
CHAIN_ID="${CHAIN_ID:-100100}"
BLOCK_GAS_LIMIT="${BLOCK_GAS_LIMIT:-20000000}"
BLOCK_TIME="${BLOCK_TIME:-2}"
PREMINE_ADDRESS="${PREMINE_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
PREMINE_BALANCE="${PREMINE_BALANCE:-1000000000000000000000000}" # 1M ETH in wei

VALIDATORS=(validator-1 validator-2 validator-3 validator-4)

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  TLH Private Trust Chain — Init                         ║"
echo "║  Chain ID: $CHAIN_ID                                    ║"
echo "║  Validators: ${#VALIDATORS[@]}                                        ║"
echo "║  Consensus: IBFT 2.0                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1: Clean previous data ────────────────────────────────────
if [ -d "$DATA_DIR" ] && [ "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "[1/3] Cleaning previous data..."
    rm -rf "$DATA_DIR"
fi
mkdir -p "$DATA_DIR"

# ── Step 2: Generate validator secrets ──────────────────────────────
echo "[2/3] Generating validator secrets..."

VALIDATOR_ADDRESSES=()
BOOTNODE_MULTIADDRS=()

for i in "${!VALIDATORS[@]}"; do
    name="${VALIDATORS[$i]}"
    dir="$DATA_DIR/$name"
    mkdir -p "$dir"

    echo "  → Generating secrets for $name..."
    output=$(docker run --rm \
        -v "$dir:/data" \
        "$IMAGE" \
        secrets init --data-dir /data --json --insecure 2>&1)

    # Extract node ID and address from JSON output
    node_id=$(echo "$output" | grep -o '"node_id":"[^"]*"' | head -1 | cut -d'"' -f4)
    address=$(echo "$output" | grep -o '"address":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$node_id" ] || [ -z "$address" ]; then
        echo "  ERROR: Failed to extract secrets for $name"
        echo "  Output: $output"
        exit 1
    fi

    VALIDATOR_ADDRESSES+=("$address")
    # libp2p port = 10001 + index
    port=$((10001 + i))
    BOOTNODE_MULTIADDRS+=("/dns4/$name/tcp/$port/p2p/$node_id")

    echo "    Address: $address"
    echo "    Node ID: ${node_id:0:16}..."
done

echo ""

# ── Step 3: Generate genesis.json ───────────────────────────────────
echo "[3/3] Generating genesis.json..."

# Build validator flags
IBFT_FLAGS=()
for addr in "${VALIDATOR_ADDRESSES[@]}"; do
    IBFT_FLAGS+=(--ibft-validator "$addr")
done

# Build bootnode flags
BOOT_FLAGS=()
for bn in "${BOOTNODE_MULTIADDRS[@]}"; do
    BOOT_FLAGS+=(--bootnode "$bn")
done

docker run --rm \
    -v "$DATA_DIR:/data" \
    -v "$ROOT_DIR:/output" \
    "$IMAGE" \
    genesis \
    --consensus ibft \
    "${IBFT_FLAGS[@]}" \
    "${BOOT_FLAGS[@]}" \
    --premine "$PREMINE_ADDRESS:$PREMINE_BALANCE" \
    --chain-id "$CHAIN_ID" \
    --block-gas-limit "$BLOCK_GAS_LIMIT" \
    --epoch-size 100000 \
    --dir /output/genesis.json

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Init complete!"
echo "  Genesis:    $ROOT_DIR/genesis.json"
echo "  Data dir:   $DATA_DIR/"
echo ""
echo "  Next: docker compose up -d"
echo "═══════════════════════════════════════════════════════════"
