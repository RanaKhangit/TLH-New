# Chainlink Node Local Setup

## Quick Start

### Step 1: Navigate to the Directory

```bash
cd chainlink-node
```

### Step 2: Create Configuration Files

We need to copy the template files to create our actual configuration:

```bash
# Copy environment template
cp .env.example .env

# Copy secrets template
cp config/secrets.toml.example config/secrets.toml
```

### Step 3: Configure the Node

We need to edit `.env` with our credentials:

```bash
# Required: PostgreSQL password - we also need to put this in the Database URL below
POSTGRES_PASSWORD=your_secure_postgres_password

# Required: Our Alchemy API key
ALCHEMY_API_KEY=your_alchemy_api_key
```

We also need to edit `config/secrets.toml`:

```toml
[Database]
URL = 'postgresql://postgres:your_secure_postgres_password@postgres:5432/chainlink?sslmode=disable'
AllowSimplePasswords = true

[Password]
Keystore = 'your_keystore_password_min_16_chars'
```

Then we need to update `config/config.toml` with our RPC URLs:

```toml
[[EVM.Nodes]]
Name = 'Sepolia-Primary'
WSURL = 'wss://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY'
HTTPURL = 'https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_API_KEY'
```

### Step 4: Create API Credentials File

We need to create the API credentials file for our initial login:

```bash
cat > config/api.txt << 'EOF'
your-email@example.com
YourSecurePassword16+
EOF
```

### Step 5: Start the Node

We can now start all services:

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f chainlink
```

### Step 6: Access the Web UI

1. We open our browser to: **http://localhost:6688**
2. We log in with the credentials from `config/api.txt`
3. We complete the initial setup wizard

### Step 7: Fund the Node

1. In the web UI, we go to **Keys** > **EVM Chain Accounts**
2. We copy our node's ETH address
3. We send testnet ETH and LINK to this address using the faucets

## Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `POSTGRES_PASSWORD` | PostgreSQL password | Yes |
| `ALCHEMY_API_KEY` | Alchemy API key | Yes |
| `KEYSTORE_PASSWORD` | Node keystore password (16+ chars) | Yes |

### Supported Networks

| Network | Chain ID | LINK Contract |
|---------|----------|---------------|
| Sepolia (Testnet) | 11155111 | `0x779877A7B0D9E8603169DdbD7836e478b4624789` |
| Ethereum Mainnet | 1 | `0x514910771AF9Ca656af840dff83E8264EcF986CA` |
| Polygon Mainnet | 137 | `0xb0897686c545045aFc77CF20eC7A532E3120E0F1` |
| Arbitrum One | 42161 | `0xf97f4df75117a78c1A5a0DBb814Af92458539FB4` |

To add additional networks, we can uncomment and configure the relevant sections in `config/config.toml`.

## DECO Verification Flow

This setup includes a DECO verification flow that:
1. Uses the DECO Sandbox (web UI) to generate attestations
2. Verifies the attestation locally via prover-api
3. Sends a transaction with PASS/FAIL result via Chainlink External Adapter

### Architecture

```
DECO Sandbox (Web UI)
         |
         v
json-encoded-attestation.json + decoded-attested-data.json (in repo root)
         |
         v
prover-api (port 8787) - Verifies signature + predicates
         |
         v
External Adapter (port 8788) - Calls prover-api, sends tx
         |
         v
Chainlink Node - Triggers External Adapter via job
         |
         v
Sepolia Blockchain - Transaction with "PASS|proofId" or "FAIL|proofId"
```

### Running the DECO Verification Flow

**Step 1: Start the prover-api (in a terminal)**

```bash
cd prover-api
npm run dev
```

This starts the verification server on http://localhost:8787

**Step 2: Start the External Adapter (in another terminal)**

```bash
cd chainlink-node/external-adapter
npm run dev
```

This starts the external adapter on http://localhost:8788

**Step 3: Configure Bridge in Chainlink Node**

We need to add the external adapter as a bridge in the Chainlink node:

1. Open http://localhost:6688 (Chainlink web UI)
2. Go to **Bridges** > **New Bridge**
3. Add:
   - Name: `deco-adapter`
   - URL: `http://host.docker.internal:8788`
   - Confirmations: `0`
   - Minimum Contract Payment: `0`

**Step 4: Create the Job**

1. Go to **Jobs** > **New Job**
2. Paste the contents of `jobs/deco-verification-job.toml`
3. Click **Create Job**

**Step 5: Trigger the Job**

Option A - Via Chainlink UI:
1. Go to **Jobs** > Select the job
2. Click **Run** to trigger manually

Option B - Via API:
```bash
curl -X POST http://localhost:6688/v2/jobs/<job_id>/runs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_token>" \
  -d '{}'
```

### Testing Without Chainlink Node

We can test the external adapter directly:

```bash
# Test the external adapter
curl -X POST http://localhost:8788 \
  -H "Content-Type: application/json" \
  -d '{"id": "test-1", "data": {}}'
```

Expected response:
```json
{
  "jobRunID": "test-1",
  "statusCode": 200,
  "data": {
    "result": "0x...",
    "txHash": "0x...",
    "proofId": "0xaecebb...",
    "verificationResult": "PASS"
  }
}
```

### Viewing Results

After a successful run, we can view the transaction on Sepolia Etherscan:
- https://sepolia.etherscan.io/tx/<txHash>

The transaction data will contain the hex-encoded string like `PASS|0xaecebb1e959f8016a9`
