# DECO Identity Verification Demo

This repository contains two different approaches to verify DECO attestations and submit results on-chain. Both demos use the same DECO attestation files but differ in architecture.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [DECO Attestation Files](#deco-attestation-files)
3. [Demo 1: Node-Centric (Chainlink Node + External Adapter)](#demo-1-node-centric-chainlink-node--external-adapter)
4. [Demo 2: CRE-Centric (Chainlink Runtime Environment)](#demo-2-cre-centric-chainlink-runtime-environment)
5. [Architecture Comparison](#architecture-comparison)

---

## Prerequisites

- **Docker** installed and running
- **Node.js** v18+ installed
- **npm** installed
- **Sepolia ETH** for transaction fees (get from faucet)

### Generate DECO Attestation (One-time Setup)

Before running either demo, you need DECO attestation files from the DECO Sandbox:

1. Go to [DECO Sandbox](https://deco.chain.link/sandbox)
2. Configure your Identity Check use case (Persona)
3. Click "Run" to generate the attestation
4. Export the files to the repo root:
   - `json-encoded-attestation.json`
   - `decoded-attested-data.json`

---

## DECO Attestation Files

Both demos use these files in the repo root:

| File | Description |
|------|-------------|
| `json-encoded-attestation.json` | Raw DECO attestation with signature |
| `decoded-attested-data.json` | Decoded data showing predicates and public outputs |

Example `json-encoded-attestation.json`:
```json
{
  "signature_scheme": "ecdsa_secp256k1_keccak256",
  "attestation_scheme": "json",
  "data_hex": "0x7b22737563636573...",
  "signature_hex": "0xaecebb1e959f8016...",
  "public_key_hex": "0x04a8a87d024e5759..."
}
```

---

## Demo 1: Node-Centric (Chainlink Node + External Adapter)

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NODE-CENTRIC DEMO FLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │   TRIGGER    │  (Manual via UI, Webhook, or Cron)
    └──────┬───────┘
           │
           ▼
    ┌──────────────────────────────────────────┐
    │         CHAINLINK NODE (Docker)          │
    │         http://localhost:6688            │
    │                                          │
    │  ┌────────────────────────────────────┐  │
    │  │  Job: deco-verification-job.toml  │  │
    │  │  - type: webhook                   │  │
    │  │  - calls bridge: "deco-adapter"    │  │
    │  └────────────────────────────────────┘  │
    └──────────────────┬───────────────────────┘
                       │
                       │ HTTP POST (bridge call)
                       ▼
    ┌──────────────────────────────────────────┐
    │       EXTERNAL ADAPTER (Your Machine)    │
    │       http://localhost:8788              │
    │                                          │
    │  chainlink-node/external-adapter/        │
    │  - Receives job request                  │
    │  - Calls prover-api for verification     │
    │  - Sends tx with result                  │
    └──────────────────┬───────────────────────┘
                       │
                       │ HTTP GET /deco/verify
                       ▼
    ┌──────────────────────────────────────────┐
    │         PROVER API (Your Machine)        │
    │         http://localhost:8787            │
    │                                          │
    │  prover-api/src/server.ts                │
    │  - Loads attestation files from disk     │
    │  - Verifies ECDSA signature (secp256k1)  │
    │  - Checks predicates passed              │
    │  - Returns { result: "PASS"|"FAIL" }     │
    └──────────────────┬───────────────────────┘
                       │
                       │ Verification result
                       ▼
    ┌──────────────────────────────────────────┐
    │       EXTERNAL ADAPTER (continued)       │
    │                                          │
    │  - Encodes result as hex: "PASS|proofId" │
    │  - Sends self-transfer tx to Sepolia     │
    │  - Uses its own wallet (PRIVATE_KEY)     │
    └──────────────────┬───────────────────────┘
                       │
                       │ sendTransaction()
                       ▼
    ┌──────────────────────────────────────────┐
    │           SEPOLIA BLOCKCHAIN             │
    │                                          │
    │  Transaction data (decoded):             │
    │  "PASS|0xaecebb1e959f8016"              │
    │                                          │
    │  View: https://sepolia.etherscan.io/tx/  │
    └──────────────────────────────────────────┘
```

### What Runs Where

| Component | Location | Port | Code Path |
|-----------|----------|------|-----------|
| Chainlink Node | Docker container | 6688 | `chainlink-node/docker-compose.yml` |
| PostgreSQL | Docker container | 5432 | (part of docker-compose) |
| External Adapter | Your machine | 8788 | `chainlink-node/external-adapter/` |
| Prover API | Your machine | 8787 | `prover-api/` |

### Step-by-Step Instructions

#### Step 1: Start Docker

```bash
# Make sure Docker is running
open -a Docker  # macOS
# or: systemctl start docker  # Linux
```

#### Step 2: Start the Chainlink Node

```bash
cd chainlink-node
docker compose up -d

# Wait for it to start, then check logs
docker logs chainlink-node -f
```

You should see: `Chainlink booted in X.XXs` and `Listening and serving HTTP on 0.0.0.0:6688`

#### Step 3: Start the Prover API

Open a **new terminal**:

```bash
cd prover-api
npm install
npm run dev
```

You should see: `prover-api listening on http://127.0.0.1:8787`

#### Step 4: Start the External Adapter

Open a **new terminal**:

```bash
cd chainlink-node/external-adapter
npm install
npm run dev
```

You should see: `DECO External Adapter running on http://localhost:8788`

#### Step 5: Configure the Chainlink Node

1. Open http://localhost:6688 in your browser
2. Login with:
   - Email: `admin@pixelette.local`
   - Password: `PixeletteChainlink2024!`

3. **Add the Bridge:**
   - Go to **Bridges** → **New Bridge**
   - Name: `deco-adapter`
   - URL: `http://host.docker.internal:8788`
   - Click **Create Bridge**

4. **Create the Job:**
   - Go to **Jobs** → **New Job**
   - Paste the following TOML:

```toml
type = "webhook"
schemaVersion = 1
name = "deco-verification"
externalJobID = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"

observationSource = """
    fetch_and_verify [type="bridge" name="deco-adapter" requestData="{\\"id\\": \\"deco-verify\\", \\"data\\": {}}"]

    parse_result [type="jsonparse" path="data,txHash" data="$(fetch_and_verify)"]

    fetch_and_verify -> parse_result
"""
```
   - Click **Create Job**

#### Step 6: Run the Demo

**Option A: Via Chainlink UI**
1. Go to **Jobs** → Click on `deco-verification`
2. Click **Run** button

**Option B: Test External Adapter Directly (skip Chainlink node)**
```bash
curl -X POST http://localhost:8788 \
  -H "Content-Type: application/json" \
  -d '{"id": "test-1", "data": {}}'
```

#### Step 7: View the Result

The response will include a `txHash`. View it on Etherscan:

```
https://sepolia.etherscan.io/tx/<txHash>
```

Click on "Input Data" → "View as UTF-8" to see: `PASS|0xaecebb1e959f8016`

### Stopping the Demo

```bash
# Stop Chainlink node
cd chainlink-node
docker compose down

# Stop prover-api and external-adapter with Ctrl+C in their terminals
```

---

## Demo 2: CRE-Centric (Chainlink Runtime Environment)

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CRE-CENTRIC DEMO FLOW                              │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────┐
    │              HTTP TRIGGER                │
    │   POST attestation JSON to workflow      │
    └──────────────────┬───────────────────────┘
                       │
                       │ HTTP POST with attestation body
                       ▼
    ┌──────────────────────────────────────────────────────────────────────┐
    │                    CRE WORKFLOW (Simulated Locally)                  │
    │                                                                      │
    │  cre-workflow/tls-cre-poc/deco-verification-workflow/main.ts        │
    │                                                                      │
    │  ┌────────────────────────────────────────────────────────────────┐  │
    │  │  1. Receive attestation via HTTP trigger                       │  │
    │  │  2. Validate signature scheme is "ecdsa_secp256k1_keccak256"   │  │
    │  │  3. Verify signature (stub - checks format + pubkey match)     │  │
    │  │  4. Parse attested data from hex                               │  │
    │  │  5. Check all predicates passed (success array)                │  │
    │  │  6. Return VerificationResult                                  │  │
    │  └────────────────────────────────────────────────────────────────┘  │
    │                                                                      │
    │  NOTE: In production, this runs on Chainlink's DON (decentralized)  │
    │        Locally, we simulate with `cre workflow simulate`            │
    └──────────────────┬───────────────────────────────────────────────────┘
                       │
                       │ Returns VerificationResult
                       ▼
    ┌──────────────────────────────────────────┐
    │          VERIFICATION RESULT             │
    │                                          │
    │  {                                       │
    │    valid: true,                          │
    │    signatureValid: true,                 │
    │    predicatesPassed: true,               │
    │    verificationType: "government-id",    │
    │    attestationHash: "0x..."              │
    │  }                                       │
    └──────────────────────────────────────────┘

    ┌─────────────────────────────────────────────────────────────────────┐
    │  NOTE: The CRE workflow does NOT send a transaction in this demo.  │
    │  In production CRE, you would add a "write" capability to submit   │
    │  the result on-chain via Chainlink's managed infrastructure.       │
    └─────────────────────────────────────────────────────────────────────┘
```

### Alternative: Standalone Script (Full Verification + TX)

For a complete end-to-end demo without CRE simulation overhead:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STANDALONE SCRIPT FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────┐
    │            RUN SCRIPT                    │
    │   npm run verify (in deco-scripts/)      │
    └──────────────────┬───────────────────────┘
                       │
                       ▼
    ┌──────────────────────────────────────────┐
    │      deco-scripts/src/verify-and-        │
    │            submit.ts                     │
    │                                          │
    │  1. Load attestation files from disk     │
    │  2. REAL secp256k1 signature verify      │
    │     (using @noble/curves)                │
    │  3. Check predicates                     │
    │  4. Send tx to Sepolia                   │
    └──────────────────┬───────────────────────┘
                       │
                       │ sendTransaction()
                       ▼
    ┌──────────────────────────────────────────┐
    │           SEPOLIA BLOCKCHAIN             │
    └──────────────────────────────────────────┘
```

### What Runs Where

| Component | Location | Code Path |
|-----------|----------|-----------|
| CRE Workflow | Local simulation | `cre-workflow/tls-cre-poc/deco-verification-workflow/` |
| Standalone Script | Your machine | `deco-scripts/src/verify-and-submit.ts` |

### Step-by-Step Instructions

#### Option A: CRE Workflow Simulation

> **Note:** This requires the CRE CLI. If you don't have it, use Option B instead.

```bash
cd cre-workflow/tls-cre-poc/deco-verification-workflow

# Install dependencies
npm install

# Simulate the workflow with test input
cre workflow simulate \
  --config config.staging.json \
  --input '{"signature_scheme":"ecdsa_secp256k1_keccak256",...}'
```

#### Option B: Standalone Script (Recommended for Demo)

This is the simplest way to demonstrate DECO verification + on-chain submission:

##### Step 1: Set up environment

```bash
cd deco-scripts
npm install
```

##### Step 2: Configure .env

Create `deco-scripts/.env` if it doesn't exist:

```bash
# Copy from the CRE workflow env
cp ../cre-workflow/tls-cre-poc/.env .env
```

Or create manually with:
```
CRE_ETH_PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.ethereum.validationcloud.io/v1/lll0Mm6Ti3NvCS1etac3ZwBpdVutGaNLyYjjjQn-YHg
```

##### Step 3: Run the verification script

```bash
npm run verify
```

##### Step 4: View the Result

The script will output:
```
=== DECO Attestation Verification ===
Signature scheme: ecdsa_secp256k1_keccak256
Verifying signature...
Signature valid: true
All predicates passed: true
Sending transaction to Sepolia...
Transaction hash: 0x...
View on Etherscan: https://sepolia.etherscan.io/tx/0x...
```

---

## Architecture Comparison

### Side-by-Side Comparison

```
┌────────────────────────────────────┬────────────────────────────────────┐
│       NODE-CENTRIC (Demo 1)        │       CRE-CENTRIC (Demo 2)         │
├────────────────────────────────────┼────────────────────────────────────┤
│                                    │                                    │
│  ┌──────────────┐                  │  ┌──────────────┐                  │
│  │   Trigger    │                  │  │   Trigger    │                  │
│  └──────┬───────┘                  │  └──────┬───────┘                  │
│         │                          │         │                          │
│         ▼                          │         ▼                          │
│  ┌──────────────┐                  │  ┌──────────────┐                  │
│  │  Chainlink   │ ◄── You run     │  │  Chainlink   │ ◄── They run     │
│  │    Node      │     this         │  │    DON       │     this         │
│  └──────┬───────┘                  │  └──────┬───────┘                  │
│         │                          │         │                          │
│         ▼                          │         ▼                          │
│  ┌──────────────┐                  │  ┌──────────────┐                  │
│  │  External    │ ◄── You run     │  │     CRE      │ ◄── Your code    │
│  │   Adapter    │     this         │  │   Workflow   │     runs here    │
│  └──────┬───────┘                  │  └──────┬───────┘                  │
│         │                          │         │                          │
│         ▼                          │         ▼                          │
│  ┌──────────────┐                  │  ┌──────────────┐                  │
│  │  Prover API  │ ◄── You run     │  │  (Built-in   │                  │
│  │              │     this         │  │   verify)    │                  │
│  └──────┬───────┘                  │  └──────┬───────┘                  │
│         │                          │         │                          │
│         ▼                          │         ▼                          │
│  ┌──────────────┐                  │  ┌──────────────┐                  │
│  │   Sepolia    │                  │  │   Sepolia    │                  │
│  │  Blockchain  │                  │  │  Blockchain  │                  │
│  └──────────────┘                  │  └──────────────┘                  │
│                                    │                                    │
├────────────────────────────────────┼────────────────────────────────────┤
│  YOU OPERATE:                      │  YOU OPERATE:                      │
│  - Chainlink Node (Docker)         │  - Nothing (just deploy code)      │
│  - External Adapter                │                                    │
│  - Prover API                      │  CHAINLINK OPERATES:               │
│  - Your own wallet for tx          │  - DON infrastructure              │
│                                    │  - Transaction submission          │
├────────────────────────────────────┼────────────────────────────────────┤
│  TRUST MODEL:                      │  TRUST MODEL:                      │
│  Centralized (your infra)          │  Decentralized (DON consensus)     │
├────────────────────────────────────┼────────────────────────────────────┤
│  BEST FOR:                         │  BEST FOR:                         │
│  - Development                     │  - Production                      │
│  - Testing                         │  - High-trust applications         │
│  - Understanding the flow          │  - When you can't run infra        │
└────────────────────────────────────┴────────────────────────────────────┘
```

### Key Differences

| Aspect | Node-Centric | CRE-Centric |
|--------|--------------|-------------|
| Infrastructure | You run everything | Chainlink runs infrastructure |
| Trust | Single point (your servers) | Decentralized (multiple nodes) |
| Complexity | More moving parts | Simpler deployment |
| Cost | Your server costs | Chainlink fees (LINK) |
| Local testing | Full end-to-end | Simulation only |
| Production ready | No (centralized) | Yes (decentralized) |

---

## Quick Reference

### All Commands Summary

```bash
# === DEMO 1: Node-Centric ===

# Terminal 1: Start Chainlink node
cd chainlink-node && docker compose up -d

# Terminal 2: Start Prover API
cd prover-api && npm install && npm run dev

# Terminal 3: Start External Adapter
cd chainlink-node/external-adapter && npm install && npm run dev

# Test External Adapter directly
curl -X POST http://localhost:8788 -H "Content-Type: application/json" -d '{"id":"test","data":{}}'

# Stop everything
cd chainlink-node && docker compose down


# === DEMO 2: Standalone Script ===

# Run verification + submit tx
cd deco-scripts && npm install && npm run verify
```

### Port Reference

| Service | Port | URL |
|---------|------|-----|
| Chainlink Node UI | 6688 | http://localhost:6688 |
| PostgreSQL | 5432 | localhost:5432 |
| Prover API | 8787 | http://localhost:8787 |
| External Adapter | 8788 | http://localhost:8788 |

### Environment Files

| File | Purpose |
|------|---------|
| `chainlink-node/.env` | Chainlink node config |
| `chainlink-node/external-adapter/.env` | External adapter wallet + RPC |
| `cre-workflow/tls-cre-poc/.env` | CRE workflow config |
| `deco-scripts/.env` | Standalone script config |

---

## Troubleshooting

### Chainlink Node won't start
```bash
# Check logs
docker logs chainlink-node

# Common fix: ensure Docker is running
open -a Docker
```

### External Adapter can't reach Prover API
```bash
# Make sure prover-api is running on port 8787
curl http://localhost:8787/health
```

### Bridge call fails from Chainlink node
- Ensure bridge URL is `http://host.docker.internal:8788` (not `localhost`)
- This is because the Chainlink node runs in Docker and needs to reach your host machine

### Transaction fails
- Check wallet has Sepolia ETH
- Verify RPC URL is working: `curl -X POST https://sepolia.ethereum.validationcloud.io/v1/lll0Mm6Ti3NvCS1etac3ZwBpdVutGaNLyYjjjQn-YHg -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`
