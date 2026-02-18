# TLH — Trusted Linked Healthcare
## CTO Technical Review Document

**Date:** February 2026
**Repo:** `https://github.com/RanaKhangit/TLH-New`
**Branch:** `main`
**Status:** Fully functional on Sepolia testnet with live demo data

---

## 1. Executive Summary

TLH is a **decentralized credential verification system** for the NHS. It uses **Chainlink DECO** (zero-knowledge TLS attestations) to verify healthcare professionals' credentials (e.g., GMC registration) and anchors the results on Ethereum. This eliminates manual, duplicated credential checks when clinicians move between NHS Trusts.

**Key capabilities:**
- Privacy-preserving verification of web-based credentials (GMC register)
- Tamper-proof on-chain attestation records (Sepolia, mainnet-ready)
- Cross-chain credential sharing via Chainlink CCIP
- Role-based access control on all contracts (UUPS upgradeable proxies)
- Full-stack: smart contracts + backend services + frontend dashboard

---

## 2. Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│                        FRONTEND (Next.js 16)                    │
│   Dashboard │ Verify Credential │ DID Explorer │ Credentials   │
│                    │ Attestation Viewer                          │
│                    Port 3000                                     │
└────────────┬──────────────┬──────────────┬─────────────────────┘
             │              │              │
             ▼              ▼              ▼
┌────────────────┐ ┌───────────────┐ ┌──────────────────────────┐
│  Prover API    │ │   External    │ │  Ethereum Sepolia        │
│  (Express)     │ │   Adapter     │ │  (5 UUPS Proxy Contracts)│
│  Port 8787     │ │   (Express)   │ │                          │
│                │ │   Port 8788   │ │  DIDRegistry             │
│  • DECO verify │ │               │ │  VCHashAnchors           │
│  • GMC lookup  │ │  • Verify     │ │  CredentialRegistry      │
│  • Signature   │ │  • Encode     │ │  AttestationVerifier     │
│    validation  │ │  • Send Tx    │ │  TrustAttestationVerifier│
└────────────────┘ └───────────────┘ └──────────────────────────┘
                                              │
                                     ┌────────┴────────┐
                                     │  Chainlink CCIP  │
                                     │  (Cross-chain)   │
                                     └─────────────────┘
```

### Data Flow (End-to-End Verification)

```
1. User clicks "Submit to Sepolia" on frontend
2. Frontend POSTs to External Adapter (:8788)
3. EA calls Prover API (:8787) → GET /deco/verify
4. Prover API loads DECO attestation files
5. Verifies ECDSA secp256k1 signature (via @noble/curves)
6. Checks all predicate success flags
7. Returns { result: "PASS", proofId: "0x..." }
8. EA encodes "PASS|0x<proofId>" as hex calldata
9. EA sends self-transfer tx to Sepolia (0 ETH, data = result)
10. Returns txHash to frontend
11. Frontend displays transaction confirmation
```

---

## 3. Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Smart Contracts** | Solidity + Foundry | 0.8.24 |
| **Contract Pattern** | UUPS Proxy (OpenZeppelin) | 5.x |
| **Frontend** | Next.js (App Router) + React | 16.1.6 / 19.2.3 |
| **Styling** | Tailwind CSS | 4.x |
| **Web3 Client** | Wagmi + Viem | 3.4.4 / 2.46.1 |
| **Backend** | Express (TypeScript) | 5.x |
| **Crypto** | @noble/curves (secp256k1) | 1.4.0 |
| **Cross-chain** | Chainlink CCIP | — |
| **Private Chain** | Polygon Edge (IBFT 2.0) | — |
| **Containerization** | Docker Compose | — |
| **Testing** | Foundry (forge test) | — |

---

## 4. Smart Contracts (Sepolia)

All contracts are deployed as **UUPS upgradeable proxies** with role-based access control.

| Contract | Proxy Address | Purpose |
|----------|---------------|---------|
| **DIDRegistry** | `0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a` | Stores decentralized identifiers (DIDs) for clinicians and patients |
| **VCHashAnchors** | `0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68` | Anchors verifiable credential content hashes on-chain |
| **CredentialRegistry** | `0xae4b71776fab8e431cee4874ad3a2a97588d89fb` | Stores credential status (Active/Expired/Revoked) with live expiry |
| **AttestationVerifier** | `0xce863e465f21df87ad9f0a2af838fac1750f08d2` | Shared anchor — verifies signed attestations, triggers DID + VC writes |
| **TrustAttestationVerifier** | `0x2ad7540b14585ebfb3c86604d1927b40e2efa5db` | Trust chain — verifies attestations and writes to CredentialRegistry |

**Deployer / Admin:** `0x3b50966a8b71f277e90e14cdc31455f6af3977e6`

### Role-Based Access

| Role | Contract | Who Has It | What It Allows |
|------|----------|------------|----------------|
| REGISTRAR_ROLE | DIDRegistry | Admin | Register new DIDs |
| ANCHOR_WRITER_ROLE | VCHashAnchors | AttestationVerifier, Admin | Write VC hash anchors |
| VERIFIER_ROLE | CredentialRegistry | TrustAttestationVerifier, Admin | Write/revoke credentials |
| SIGNER_ADMIN_ROLE | Both Verifiers | Admin | Whitelist attestation signers |
| UPGRADER_ROLE | All contracts | Admin | Upgrade implementations |

### Contract Interaction Diagram

```
submitAttestation(id, subjectDID, predicateData, signature)
          │
          ▼
  BaseAttestationVerifier._verifyAndStore()
    ├── Check replay protection (attestationUsed[id])
    ├── Decode predicateData[0] = result byte
    ├── Verify ECDSA signature against chain-bound digest
    ├── Check signer whitelist
    ├── Store attestation record
    └── Call _onAttestationVerified() hook
              │
    ┌─────────┴──────────┐
    ▼                    ▼
  AttestationVerifier  TrustAttestationVerifier
  (Shared Anchor)      (Trust Chain)
    │                    │
    ├── registerDID()    └── writeCredential()
    ├── anchorHash()         to CredentialRegistry
    └── emit events
```

---

## 5. Project Directory Structure

```
tlh/
├── contracts/                    # Solidity smart contracts (Foundry)
│   ├── src/
│   │   ├── shared/               # DIDRegistry, VCHashAnchors, AttestationVerifier
│   │   ├── trust/                # CredentialRegistry, TrustAttestationVerifier
│   │   ├── ccip/                 # CCIP sender/receiver contracts
│   │   ├── base/                 # BaseAttestationVerifier (shared logic)
│   │   └── interfaces/           # Contract interfaces
│   ├── test/                     # Foundry tests
│   ├── script/                   # Deployment & seed scripts
│   │   ├── DeploySepolia.s.sol
│   │   ├── DeployPrivateChain.s.sol
│   │   ├── DeployCCIP.s.sol
│   │   ├── SeedDemoData.s.sol
│   │   ├── SeedAttestation.s.sol
│   │   └── SeedTrustAttestation.s.sol
│   ├── broadcast/                # Deployment tx logs (Sepolia)
│   ├── deployment-manifest.sepolia.json
│   └── foundry.toml
│
├── frontend/                     # Next.js 16 dashboard
│   ├── src/
│   │   ├── app/                  # 5 pages: /, /verify, /did, /credentials, /attestations
│   │   ├── components/ui/        # Shared: Card, Badge, Skeleton, ErrorBoundary
│   │   ├── hooks/                # Contract read hooks (wagmi)
│   │   └── lib/                  # ABIs, API client, utils, wagmi config
│   └── package.json
│
├── prover-api/                   # DECO attestation verifier (Express)
│   ├── src/server.ts
│   └── package.json
│
├── chainlink-node/               # Chainlink Node (Docker) + External Adapter
│   ├── docker-compose.yml        # Chainlink Node + PostgreSQL
│   ├── config/                   # config.toml, secrets.toml, api.txt
│   ├── jobs/                     # TOML job specs
│   └── external-adapter/         # Express service (sends txs to Sepolia)
│       ├── src/index.ts
│       ├── .env.example
│       └── package.json
│
├── private-chain/                # Polygon Edge (4-validator IBFT 2.0)
│   ├── docker-compose.yml
│   └── scripts/
│
├── cre-workflow/                  # Chainlink Runtime Environment workflows
├── deco-scripts/                  # Standalone DECO verification scripts
├── START-HERE.md                  # Step-by-step setup guide
├── DEMO-README.md                 # Architecture documentation
└── TESTING_GUIDE.md               # Testing procedures
```

---

## 6. How to Run (Quick Start)

### Prerequisites

| Requirement | Check | Notes |
|-------------|-------|-------|
| Node.js 18+ | `node --version` | Required for all services |
| npm | `npm --version` | Bundled with Node.js |
| Docker + Compose | `docker --version` | For Chainlink Node |
| Foundry (forge) | `forge --version` | For contract compilation/deployment |
| Sepolia ETH | — | ~0.05 ETH for gas fees |
| Alchemy API key | — | For Sepolia RPC access |

### Step 1: Clone & Install

```bash
git clone --recurse-submodules https://github.com/RanaKhangit/TLH-New.git
cd TLH-New
```

### Step 2: Configure Environment

```bash
# External Adapter (REQUIRED)
cp chainlink-node/external-adapter/.env.example chainlink-node/external-adapter/.env
# Edit .env → set PRIVATE_KEY and SEPOLIA_RPC_URL
```

### Step 3: Install Dependencies

```bash
# Frontend
cd frontend && npm install && cd ..

# Prover API
cd prover-api && npm install && cd ..

# External Adapter
cd chainlink-node/external-adapter && npm install && cd ../..
```

### Step 4: Start Services (3 terminals)

```bash
# Terminal 1 — Prover API
cd prover-api && npm run dev
# → http://localhost:8787

# Terminal 2 — External Adapter
cd chainlink-node/external-adapter && npm run dev
# → http://localhost:8788

# Terminal 3 — Frontend
cd frontend && npm run dev
# → http://localhost:3000
```

### Step 5: Verify

```bash
# Health checks
curl http://localhost:8787/health    # {"ok":true}
curl http://localhost:8788/health    # {"status":"ok","address":"0x..."}

# Full pipeline test (verify + send tx)
curl -X POST http://localhost:8788 \
  -H "Content-Type: application/json" \
  -d '{"id":"test","data":{}}'
# → {"statusCode":200,"data":{"txHash":"0x...","verificationResult":"PASS"}}
```

### Step 6: Open Frontend

Navigate to `http://localhost:3000` and explore:
1. **Dashboard** — Contract deployment status, service health
2. **Verify Credential** — Load attestation → Verify → Submit to Sepolia → GMC lookup
3. **DID Explorer** — Resolve registered DIDs
4. **Credential Explorer** — Query credential status (Active/Expired/Revoked)
5. **Attestation Viewer** — Look up attestation records on both verifiers

---

## 7. Live Demo Data on Sepolia

The following data has been seeded on-chain via Forge scripts:

| Data | Details |
|------|---------|
| **DID: clinician-789** | `did:tlh:clinician-789` — registered, controller = deployer |
| **DID: patient-123** | `did:tlh:patient-123` — registered, controller = deployer |
| **Credential** | GMC_REGISTERED for clinician-789, Active, expires Feb 2027 |
| **VC Hash Anchor** | GMC_REGISTRATION content hash for clinician-789 |
| **Shared Attestation** | ID: `0x1d46629b...` — PASS result |
| **Trust Attestation** | ID: `0x8fe3f608...` — PASS result |

### Verify on Etherscan

Any transaction can be verified at:
```
https://sepolia.etherscan.io/tx/<txHash>
```
View Input Data → UTF-8 to see `PASS|0x<proofId>`.

---

## 8. Security Design

| Aspect | Implementation |
|--------|---------------|
| **Private keys** | Never committed to git. `.env` is gitignored, `.env.example` provides templates |
| **Replay protection** | `attestationUsed[id]` mapping prevents duplicate submissions |
| **Signature verification** | Chain-bound digest includes domain tag, chainId, contract address |
| **Signer whitelist** | Only whitelisted addresses can submit valid attestations |
| **Role separation** | REGISTRAR, VERIFIER, ANCHOR_WRITER, SIGNER_ADMIN, UPGRADER |
| **UUPS upgradeable** | Admin-only upgrade path, no unprotected `selfdestruct` |
| **Credential expiry** | Live status evaluation at read-time (not just write-time) |
| **Irrevocable revocation** | Once revoked, a credential cannot be reactivated |

---

## 9. Testing

### Smart Contracts
```bash
cd contracts
forge test -vvv           # Run all Foundry tests
forge test --gas-report   # With gas usage report
```

### Frontend
```bash
cd frontend
npm run lint              # ESLint check
npm run build             # Full production build (catches type errors)
```

### Services
```bash
# Prover API
cd prover-api && npm run typecheck

# External Adapter
cd chainlink-node/external-adapter && npm run typecheck
```

### Manual End-to-End Test

| Step | Page | Action | Expected |
|------|------|--------|----------|
| 1 | Dashboard `/` | Load page | All 5 contracts show addresses, services healthy |
| 2a | Verify `/verify` | Click "Load Attestation" | Shows signature scheme, attestation data |
| 2b | Verify `/verify` | Click "Verify Attestation" | Result: PASS, Proof ID shown |
| 2c | Verify `/verify` | Click "Submit to Sepolia" | Transaction hash returned |
| 2d | Verify `/verify` | GMC Lookup | Doctor record with registration status |
| 3 | DID `/did` | Enter `did:tlh:clinician-789` | DID record with controller address |
| 4 | Credentials `/credentials` | Enter clinician DID + GMC_REGISTERED | Status: Active, Valid: Yes |
| 5 | Attestations `/attestations` | Enter attestation ID | Record with PASS result and timestamp |

---

## 10. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **UUPS over Transparent Proxy** | Smaller deployment, upgrade logic in implementation (not proxy) |
| **Self-transfer tx for data anchoring** | Cheapest on-chain data storage — only calldata cost, no state writes |
| **Two separate verifiers** | Shared (public anchors) vs Trust (private credential writes) |
| **@noble/curves for signature verification** | Pure JS, no native dependencies, audited library |
| **Next.js App Router** | Server components, file-based routing, React 19 features |
| **Wagmi + Viem** | Type-safe Ethereum client, React hooks for contract reads |
| **Polygon Edge for private chain** | NHS Trusts need private, permissioned networks |
| **CCIP for cross-chain** | Chainlink's standard for cross-chain messaging between trusts |

---

## 11. What's Next (Roadmap)

| Priority | Item | Status |
|----------|------|--------|
| 1 | Mainnet deployment | Contracts are mainnet-ready, needs audit |
| 2 | CCIP cross-chain demo | Contracts deployed, frontend integration pending |
| 3 | Private chain full integration | Polygon Edge running, needs trust-chain frontend |
| 4 | Multi-trust credential sharing | Architecture designed, needs implementation |
| 5 | Production Chainlink Node | Docker setup ready, needs cloud deployment |
| 6 | Smart contract audit | All contracts follow OZ patterns, ready for audit |

---

## 12. Commit History (Recent)

```
31a06d5 chore: add Sepolia seed broadcast logs and gitmodules
06f35c4 fix(ea): add explicit gas limit for self-call tx + seed demo data on Sepolia
1b5368a feat(frontend): architectural cleanup — shared components, error boundary, skeleton loaders
6fb4adf feat: deploy trust contracts to Polygon Edge private chain
4289a25 Merge pull request #25 — feat/ccip-workstream
6c889a7 feat: add CCIP sender/receiver contracts and integration tests
b6bdee7 Merge pull request #24 — feat/frontend-qa-pass
```

---

## 13. Contact

For questions about this codebase, setup issues, or architectural decisions, contact the development team.
