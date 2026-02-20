# TLH — Trusted Linked Healthcare
## CTO Technical Review Document

**Date:** February 18, 2026
**Repo:** `https://github.com/RanaKhangit/TLH-New`
**Branch:** `main`
**Status:** Fully functional on Sepolia testnet — all services live, all 173 tests passing

---

## 1. Executive Summary

TLH is a **decentralized credential verification system** for the NHS. It uses **Chainlink DECO** (zero-knowledge TLS attestations) to verify healthcare professionals' credentials (e.g., GMC registration) and anchors the results on Ethereum. This eliminates manual, duplicated credential checks when clinicians move between NHS Trusts.

**Key capabilities:**
- Privacy-preserving verification of web-based credentials (GMC register)
- Dynamic per-doctor DECO attestation generation with ECDSA secp256k1 signing
- On-chain attestation submission via `submitAttestation()` contract calls
- Cross-chain credential sharing via Chainlink CCIP (deployed + configured)
- Private trust chain (Polygon Edge, 4-validator IBFT 2.0, chain ID 100100)
- Role-based access control on all contracts (UUPS upgradeable proxies)
- Full-stack: smart contracts + backend services + frontend dashboard

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                        FRONTEND (Next.js 16, Port 3000)              │
│   Dashboard │ Verify Credential │ DID Explorer │ Credentials        │
│                    │ Attestation Viewer                               │
│   /api/pipeline  (Next.js API route — proxies to EA)                 │
└────────────┬──────────────┬──────────────┬───────────────────────────┘
             │              │              │
             ▼              ▼              ▼
┌────────────────┐ ┌───────────────┐ ┌──────────────────────────────────┐
│  Prover API    │ │   External    │ │  Ethereum Sepolia (11155111)     │
│  (Express)     │ │   Adapter     │ │  7 UUPS Proxy Contracts:         │
│  Port 8787     │ │   (Express)   │ │                                  │
│                │ │   Port 8788   │ │  DIDRegistry                     │
│  • GMC lookup  │ │               │ │  VCHashAnchors                   │
│  • Dynamic     │ │  • Verify via │ │  CredentialRegistry              │
│    DECO attest │ │    Prover API │ │  AttestationVerifier             │
│  • ECDSA sign  │ │  • Build ADR  │ │  TrustAttestationVerifier        │
│  • Signature   │ │    predicate  │ │  TLHCCIPReceiver                 │
│    verify      │ │  • Call       │ │  TLHCCIPSender                   │
│                │ │    submit-    │ │                                  │
│                │ │    Attestation│ │                                  │
└────────────────┘ └───────────────┘ └───────────────┬──────────────────┘
                                                     │
                                            ┌────────┴────────┐
                                            │  Chainlink CCIP  │
                                            │  (Cross-chain)   │
                                            └────────┬────────┘
                                                     │
                          ┌──────────────────────────┴──────────────────┐
                          │  Private Trust Chain (Polygon Edge, 100100)  │
                          │  4 IBFT 2.0 Validators (Docker)             │
                          │                                              │
                          │  CredentialRegistry (proxy)                  │
                          │  TrustAttestationVerifier (proxy)            │
                          └─────────────────────────────────────────────┘
```

### Data Flow (End-to-End Verification Pipeline)

```
1. User selects doctor from dropdown on /verify page
2. Step 1: Frontend → Prover API → GET /gmc/lookup?surname=X&givenName=Y
   └─ Returns GMC registration record (ref number, status, qualification)

3. Step 2: Frontend → Prover API → GET /deco/verify?surname=X&givenName=Y
   ├─ Prover generates fresh DECO attestation for selected doctor
   ├─ Signs attestation data with deterministic ECDSA secp256k1 key
   ├─ Verifies signature + checks registration predicate
   └─ Returns { result: "PASS"/"FAIL", attestation: {...}, gmcRefNo, ... }

4. Step 3: Frontend → POST /api/pipeline (Next.js route → EA :8788)
   ├─ EA calls Prover API → GET /deco/verify?surname=X&givenName=Y
   ├─ EA builds ADR-002 predicateData (result byte + ABI-encoded payload)
   ├─ EA signs chain-bound digest with deployer key (EIP-191)
   ├─ EA calls submitAttestation() on AttestationVerifier contract
   │   ├─ Contract verifies ECDSA signature
   │   ├─ Contract checks signer whitelist
   │   ├─ Contract stores attestation record
   │   └─ If PASS: registers DID + anchors VC hash
   └─ Returns { txHash, attestationId, verificationResult, proofId }

5. Frontend displays tx hash (clickable Etherscan link) + attestation ID
```

**PASS path** (registered doctor): Full on-chain attestation + DID registration + VC hash anchor
**FAIL path** (deceased/removed doctor): On-chain attestation stored with result=false, no side-effects

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
| **Private Chain** | Polygon Edge (IBFT 2.0) | 1.3.3 |
| **Containerization** | Docker Compose | — |
| **Testing** | Foundry (forge test) | 1.6.0 |

---

## 4. Smart Contracts

### Sepolia (Shared Anchor Chain — 11155111)

All contracts are deployed as **UUPS upgradeable proxies** with role-based access control.

| Contract | Proxy Address | Purpose |
|----------|---------------|---------|
| **DIDRegistry** | `0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a` | Stores decentralized identifiers (DIDs) for clinicians and patients |
| **VCHashAnchors** | `0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68` | Anchors verifiable credential content hashes on-chain |
| **CredentialRegistry** | `0xae4b71776fab8e431cee4874ad3a2a97588d89fb` | Stores credential status (Active/Expired/Revoked) with live expiry |
| **AttestationVerifier** | `0xce863e465f21df87ad9f0a2af838fac1750f08d2` | Shared anchor — verifies signed attestations, triggers DID + VC writes |
| **TrustAttestationVerifier** | `0x2ad7540b14585ebfb3c86604d1927b40e2efa5db` | Trust chain — verifies attestations and writes to CredentialRegistry |
| **TLHCCIPReceiver** | `0x234Aec51d3977bA5174B068d2Daf15e5367C0bF0` | Receives cross-chain credentials via CCIP |
| **TLHCCIPSender** | `0xB8238cA59c7479e16d888A86A533A3113886A260` | Sends cross-chain credentials via CCIP |

**Deployer / Admin:** `0x3b50966a8b71f277e90e14cdc31455f6af3977e6`
**CCIP Router (Sepolia):** `0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59`

### Private Trust Chain (Polygon Edge — 100100)

| Contract | Proxy Address | Purpose |
|----------|---------------|---------|
| **CredentialRegistry** | `0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE` | Trust-chain credential storage |
| **TrustAttestationVerifier** | `0x68B1D87F95878fE05B998F19b66F4baba5De1aed` | Trust-chain attestation verifier |

**Deployer / Admin:** `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`

### Role-Based Access

| Role | Contract | Who Has It | What It Allows |
|------|----------|------------|----------------|
| REGISTRAR_ROLE | DIDRegistry | Admin | Register new DIDs |
| ANCHOR_WRITER_ROLE | VCHashAnchors | AttestationVerifier, Admin | Write VC hash anchors |
| VERIFIER_ROLE | CredentialRegistry | TrustAttestationVerifier, TLHCCIPReceiver, Admin | Write/revoke credentials |
| SIGNER_ADMIN_ROLE | Both Verifiers | Admin | Whitelist attestation signers |
| UPGRADER_ROLE | All contracts | Admin | Upgrade implementations |

### CCIP Configuration (Completed)

| Configuration | Status |
|---------------|--------|
| Receiver: `isChainAllowlisted(sepoliaSelector)` | `true` |
| Receiver: `isSenderAllowlisted(sepoliaSelector, senderProxy)` | `true` |
| Sender: `configureDestination(sepoliaSelector, receiverProxy)` | `true` |
| CredentialRegistry: `hasRole(VERIFIER_ROLE, receiverProxy)` | `true` |

### Contract Interaction Diagram

```
submitAttestation(id, subjectDID, predicateData, signature)
          │
          ▼
  BaseAttestationVerifier._verifyAndStore()
    ├── Check replay protection (attestationUsed[id])
    ├── Decode predicateData[0] = result byte
    ├── Verify ECDSA signature against chain-bound digest
    │     └── digest = EIP-191(keccak256(DOMAIN ‖ chainId ‖ contractAddr ‖ id ‖ did ‖ predHash))
    ├── Check signer whitelist (signerWhitelist[recovered])
    ├── Validate result consistency + expiry
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

## 5. Dynamic DECO Attestation System

The prover-api generates **per-doctor, freshly signed** DECO attestations (not static files).

### How It Works

1. **Deterministic Prover Key** — derived from `keccak256("TLH_DECO_PROVER_V1")` for reproducibility
2. **GMC Lookup** — reads 4 demo doctors from CSV (3 registered, 1 deceased)
3. **Attestation Generation** — builds JSON payload with:
   - `success[0]`: registration predicate (`registrationStatus.includes("Licence")`)
   - `proof_specs`: TLS proof specification (method, URL, predicate)
   - `public_outputs`: GMC ref number + registration status
   - `data_retrieval_time`: current ISO timestamp
4. **ECDSA Signing** — `secp256k1.sign(keccak256(data_hex), proverPrivKey)`
5. **Verification** — recovers public key from signature, checks against prover key, evaluates predicates

### Demo Doctors

| Name | GMC Ref | Status | DECO Result |
|------|---------|--------|-------------|
| Azhar Adfcds | 4333333 | Registered with a licence to practise | PASS |
| Rosalind Fsofkdoo | 5222222 | Registered with a licence to practise | PASS |
| Keith Hslllsp | 6111111 | Registered with a licence to practise | PASS |
| Alison Bskeodk | 7000000 | Not registered — Deceased | FAIL |

---

## 6. Project Directory Structure

```
tlh/
├── contracts/                    # Solidity smart contracts (Foundry)
│   ├── src/
│   │   ├── shared/               # DIDRegistry, VCHashAnchors, AttestationVerifier
│   │   ├── trust/                # CredentialRegistry, TrustAttestationVerifier
│   │   ├── ccip/                 # TLHCCIPSender, TLHCCIPReceiver
│   │   ├── base/                 # BaseAttestationVerifier (shared logic)
│   │   └── interfaces/           # Contract interfaces
│   ├── test/                     # 173 Foundry tests (all passing)
│   │   ├── base/                 # BaseAttestationVerifier unit tests
│   │   ├── shared/               # DIDRegistry, VCHashAnchors, AttestationVerifier
│   │   ├── trust/                # CredentialRegistry, TrustAttestationVerifier
│   │   ├── ccip/                 # CCIP integration, sender, receiver tests
│   │   └── fork/                 # Sepolia fork behaviour tests
│   ├── script/                   # Deployment & seed scripts
│   ├── broadcast/                # Deployment tx logs (Sepolia + local)
│   ├── deployment-manifest.sepolia.json
│   ├── deployment-manifest.private-chain.json
│   └── foundry.toml
│
├── frontend/                     # Next.js 16 dashboard
│   ├── src/
│   │   ├── app/                  # 5 pages + /api/pipeline route
│   │   ├── components/ui/        # Card, Badge, Skeleton, ErrorBoundary
│   │   ├── hooks/                # Contract read hooks (wagmi)
│   │   └── lib/                  # ABIs, API client, utils, wagmi config
│   └── package.json
│
├── prover-api/                   # DECO attestation engine (Express)
│   ├── src/server.ts             # Dynamic attestation generation + verification
│   ├── data/                     # Demo doctor CSV, static fallback files
│   └── package.json
│
├── chainlink-node/               # Chainlink Node (Docker) + External Adapter
│   ├── docker-compose.yml
│   └── external-adapter/         # Express — calls submitAttestation() on-chain
│       ├── src/index.ts
│       └── package.json
│
├── private-chain/                # Polygon Edge (4-validator IBFT 2.0)
│   ├── docker-compose.yml
│   └── scripts/
│
└── CTO-REVIEW.md                 # This document
```

---

## 7. How to Run (Quick Start)

### Prerequisites

| Requirement | Check | Notes |
|-------------|-------|-------|
| Node.js 18+ | `node --version` | Required for all services |
| Docker + Compose | `docker --version` | For private chain + Chainlink Node |
| Foundry (forge) | `forge --version` | For contract compilation/testing |
| Sepolia ETH | — | ~0.05 ETH for gas fees |

### Start Services

```bash
# Terminal 1 — Prover API
cd prover-api && npm install && npm run dev
# → http://localhost:8787

# Terminal 2 — External Adapter
cd chainlink-node/external-adapter && npm install && npm run dev
# → http://localhost:8788

# Terminal 3 — Frontend
cd frontend && npm install && npm run dev
# → http://localhost:3000

# Terminal 4 — Private Chain (optional)
cd private-chain && docker compose up -d
# → 4 validators on http://localhost:8545
```

### Verify Everything Works

```bash
# 1. Health checks
curl http://localhost:8787/health
# → {"ok":true}

curl http://localhost:8788/health
# → {"status":"ok","address":"0x3B50966A8B71f277e90e14cdC31455F6Af3977e6"}

# 2. GMC Lookup (dynamic)
curl "http://localhost:8787/gmc/lookup?surname=Adfcds&givenName=Azhar"
# → {"gmcRefNo":"4333333","registrationStatus":"Registered with a licence to practise",...}

# 3. DECO Verify (dynamic, per-doctor)
curl "http://localhost:8787/deco/verify?surname=Adfcds&givenName=Azhar"
# → {"result":"PASS","gmcRefNo":"4333333","attestation":{"signature_hex":"0x..."},...}

# 4. DECO Verify (FAIL path — deceased doctor)
curl "http://localhost:8787/deco/verify?surname=Bskeodk&givenName=Alison"
# → {"result":"FAIL","reason":"Registration predicate failed",...}

# 5. Full pipeline (EA → Prover → submitAttestation → Sepolia tx)
curl -X POST http://localhost:8788 \
  -H "Content-Type: application/json" \
  -d '{"id":"test","data":{"surname":"Adfcds","givenName":"Azhar"}}'
# → {"statusCode":200,"data":{"txHash":"0x...","verificationResult":"PASS","attestationId":"0x..."}}

# 6. Pipeline via frontend API route
curl -X POST http://localhost:3000/api/pipeline \
  -H "Content-Type: application/json" \
  -d '{"surname":"Adfcds","givenName":"Azhar"}'
# → Same response as above

# 7. Private chain validators
docker ps | grep tlh-validator
# → 4 containers running

# 8. Private chain RPC
curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
# → {"jsonrpc":"2.0","id":1,"result":"0x186a4"}  (100100)

# 9. All Foundry tests
cd contracts && forge test --summary
# → 14 suites | 173 passed | 0 failed | 0 skipped
```

---

## 8. Test Results (173/173 Passing)

```
╭───────────────────────────────────────+────────+────────+─────────╮
│ Test Suite                            │ Passed │ Failed │ Skipped │
╞═══════════════════════════════════════╪════════╪════════╪═════════╡
│ PlaceholderTest                       │ 1      │ 0      │ 0       │
│ BaseAttestationVerifierTest           │ 10     │ 0      │ 0       │
│ AttestationVerifierTest               │ 14     │ 0      │ 0       │
│ TrustAttestationVerifierTest          │ 12     │ 0      │ 0       │
│ DIDRegistryTest                       │ 31     │ 0      │ 0       │
│ VCHashAnchorsTest                     │ 13     │ 0      │ 0       │
│ CredentialRegistryTest                │ 26     │ 0      │ 0       │
│ CCIPIntegrationTest                   │ 4      │ 0      │ 0       │
│ TLHCCIPSenderTest                     │ 17     │ 0      │ 0       │
│ TLHCCIPReceiverTest                   │ 18     │ 0      │ 0       │
│ AttestationVerifierForkTest           │ 3      │ 0      │ 0       │
│ VCHashAnchorsForkTest                 │ 8      │ 0      │ 0       │
│ AttestationVerifierForkBehaviour      │ 8      │ 0      │ 0       │
│ TrustAttestationVerifierForkBehaviour │ 8      │ 0      │ 0       │
╰───────────────────────────────────────+────────+────────+─────────╯
  TOTAL: 173 passed, 0 failed, 0 skipped
```

### Test Categories

| Category | Count | Scope |
|----------|-------|-------|
| Unit (Solidity) | 106 | Base, shared, trust contract logic |
| CCIP | 39 | Sender, receiver, end-to-end integration |
| Fork (state checks) | 11 | On-chain wiring, roles, deployed contract state |
| Fork (behaviour) | 16 | Full submit + verify flows against live Sepolia state |
| Placeholder | 1 | Forge compilation check |

---

## 9. Frontend — Verify Credential Page

The `/verify` page implements a connected 3-step pipeline:

| Step | Action | What Happens |
|------|--------|--------------|
| **Select Doctor** | Choose from dropdown | 4 demo doctors available |
| **Step 1: GMC Lookup** | Click "Lookup GMC Registration" | Queries prover-api, shows GMC ref + status in table |
| **Step 2: DECO Verify** | Click "Generate & Verify Attestation" | Generates fresh attestation, signs with prover key, verifies signature + predicate, shows PASS/FAIL + cryptographic details |
| **Step 3: Submit On-Chain** | Click "Submit to Sepolia" | Runs full EA pipeline, calls `submitAttestation()`, returns tx hash + attestation ID |

Changing the selected doctor resets all downstream steps.

---

## 10. Security Design

| Aspect | Implementation |
|--------|---------------|
| **Private keys** | Never committed to git. `.env` is gitignored, `.env.example` provides templates |
| **Replay protection** | `attestationUsed[id]` mapping prevents duplicate submissions |
| **Signature verification** | Chain-bound digest includes domain tag, chainId, contract address (EIP-191) |
| **Signer whitelist** | Only whitelisted addresses can submit valid attestations |
| **Role separation** | REGISTRAR, VERIFIER, ANCHOR_WRITER, SIGNER_ADMIN, UPGRADER |
| **UUPS upgradeable** | Admin-only upgrade path, no unprotected `selfdestruct` |
| **Credential expiry** | Live status evaluation at read-time (not just write-time) |
| **Irrevocable revocation** | Once revoked, a credential cannot be reactivated |
| **CCIP allowlisting** | Dual allowlist: source chain + sender address |
| **CCIP nonce protection** | Monotonic nonces prevent replay + enforce ordering |

---

## 11. CTO Review Findings — Resolution Status

| # | Finding | Status | Resolution |
|---|---------|--------|------------|
| 1 | EA sends self-transfer txs (0 ETH to self) instead of calling contracts | **Fixed** | EA now calls `submitAttestation()` on AttestationVerifier contract. All txs target `0xCE863E46...` with proper ABI-encoded calldata |
| 2 | Frontend disconnected from backend services | **Fixed** | Frontend calls prover-api (GMC lookup, DECO verify) and EA (pipeline submit) with full error handling. `/api/pipeline` Next.js route added |
| 3 | Private chain not running | **Fixed** | 4 Polygon Edge IBFT 2.0 validators running in Docker (chain ID 100100). Trust contracts deployed and verified callable |
| 4 | CCIP contracts never deployed | **Fixed** | TLHCCIPSender + TLHCCIPReceiver deployed on Sepolia. Post-deployment configuration completed: source chain allowlisted, sender allowlisted, VERIFIER_ROLE granted to receiver |
| 5 | DECO attestation uses static files | **Fixed** | Prover-api now generates dynamic per-doctor attestations with fresh ECDSA signatures. PASS/FAIL paths both work correctly |
| 6 | Fork tests failing (6/173) | **Fixed** | Root cause: wrong `DEPLOYER_PRIVATE_KEY` in contracts/.env + stale fork block (before `addSigner` was called). Updated key and fork block to 10280750 |

---

## 12. Live Demo Data on Sepolia

### Seeded Data (via Forge scripts)

| Data | Details |
|------|---------|
| **DID: clinician-789** | `did:tlh:clinician-789` — registered, controller = deployer |
| **DID: patient-123** | `did:tlh:patient-123` — registered, controller = deployer |
| **Credential** | GMC_REGISTERED for clinician-789, Active, expires Feb 2027 |
| **VC Hash Anchor** | GMC_REGISTRATION content hash for clinician-789 |
| **Shared Attestation** | ID: `0x1d46629b...` — PASS result |
| **Trust Attestation** | ID: `0x8fe3f608...` — PASS result |

### Live Pipeline Transactions

Every click of "Submit to Sepolia" creates a **new, unique** transaction calling `submitAttestation()` on `0xCE863E465f21Df87Ad9F0A2af838Fac1750F08d2`.

Verify any transaction at: `https://sepolia.etherscan.io/tx/<txHash>`

---

## 13. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **UUPS over Transparent Proxy** | Smaller deployment, upgrade logic in implementation (not proxy) |
| **submitAttestation() contract calls** | Real on-chain state writes with signature verification, replay protection, and cross-contract side-effects |
| **Two separate verifiers** | Shared (public DID + VC anchors) vs Trust (private credential writes) |
| **Deterministic prover key** | `keccak256("TLH_DECO_PROVER_V1")` — reproducible for demo, replaceable in production |
| **@noble/curves for ECDSA** | Pure JS, no native dependencies, audited library |
| **Next.js App Router** | Server components, file-based routing, React 19 features |
| **Wagmi + Viem** | Type-safe Ethereum client, React hooks for contract reads |
| **Polygon Edge for private chain** | NHS Trusts need private, permissioned networks |
| **CCIP for cross-chain** | Chainlink's standard for cross-chain messaging between trusts |

---

## 14. Commit History (Recent)

```
9130687 feat: EA calls submitAttestation() on-chain + CCIP deployed on Sepolia
fbf3304 docs: add CTO technical review document
02676b5 chore: update .env.example with Alchemy RPC and deployer notes
31a06d5 chore: add Sepolia seed broadcast logs and gitmodules
06f35c4 fix(ea): add explicit gas limit for self-call tx + seed demo data on Sepolia
1b5368a feat(frontend): architectural cleanup — shared components, error boundary, skeleton loaders
6fb4adf feat: deploy trust contracts to Polygon Edge private chain (Issue #15)
4289a25 Merge pull request #25 — feat/ccip-workstream
6c889a7 feat: add CCIP sender/receiver contracts and integration tests
b6bdee7 Merge pull request #24 — feat/frontend-qa-pass
```

### Uncommitted Changes (Pending Commit)

| File | Change |
|------|--------|
| `prover-api/src/server.ts` | Dynamic DECO attestation generation per doctor |
| `chainlink-node/external-adapter/src/index.ts` | Forward doctor info to prover-api |
| `frontend/src/app/verify/page.tsx` | 3-step connected pipeline UI |
| `frontend/src/lib/api.ts` | Updated API client with doctor params |
| `frontend/src/app/api/pipeline/route.ts` | **New** — Next.js API route proxying to EA |
| `contracts/test/fork/*.t.sol` | Fixed fork block (10280750) for test determinism |

---

## 15. Contact

For questions about this codebase, setup issues, or architectural decisions, contact the development team.
