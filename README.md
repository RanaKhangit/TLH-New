# Trust Layer Health (TLH)

**Blockchain-based NHS Credential Verification Platform**

[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636?logo=solidity)](https://soliditylang.org/)
[![Chainlink](https://img.shields.io/badge/Chainlink-DECO-375BD2?logo=chainlink)](https://chain.link/)
[![Next.js](https://img.shields.io/badge/Next.js-16-000000?logo=next.js)](https://nextjs.org/)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#license)

TLH enables NHS trusts to verify clinician credentials (GMC registration, specialist qualifications) on-chain without exposing sensitive personal data. Built with Chainlink DECO attestations and a privacy-preserving dual-chain architecture.

---

## Architecture

```
                         ┌─────────────────────────────┐
                         │     Off-Chain (Chainlink)    │
                         │                              │
                         │  DECO Prover ──► DON/Relayer │
                         └──────────┬──────────┬────────┘
                                    │          │
                       signed       │          │      signed
                       attestation  │          │      attestation
                                    ▼          ▼
                ┌───────────────────────┐  ┌───────────────────────┐
                │   SHARED ANCHOR CHAIN │  │   TRUST PRIVATE CHAIN │
                │      (Sepolia)        │  │    (Polygon Edge)     │
                │                       │  │                       │
                │  AttestationVerifier  │  │ TrustAttestationVerifier │
                │         │             │  │         │              │
                │         ▼             │  │         ▼              │
                │  ┌─────────────┐      │  │  ┌───────────────┐     │
                │  │ DIDRegistry │      │  │  │ Credential    │     │
                │  └─────────────┘      │  │  │ Registry      │     │
                │  ┌─────────────┐      │  │  └───────────────┘     │
                │  │ VCHashAnchors│     │  │                        │
                │  └─────────────┘      │  │  Operational state     │
                │                       │  │  (valid/expired/       │
                │  Hashes only          │  │   revoked)             │
                │  (privacy-preserving) │  │                        │
                └───────────────────────┘  └────────────────────────┘
```

**Why two chains?**
- **Shared Anchor Chain** (Sepolia): Public provenance — anyone can verify a credential exists without seeing the data
- **Trust Private Chain** (Polygon Edge IBFT 2.0): Operational state — "is this credential still valid?" — used by the trust's internal systems

---

## Features

- **GMC Lookup** — Real-time verification against the General Medical Council register
- **DECO Attestations** — Chainlink's privacy-preserving proof system
- **On-Chain Anchoring** — Immutable credential proofs on Ethereum
- **CCIP Cross-Chain** — Credential portability via Chainlink CCIP
- **Role-Based Access** — Fine-grained permissions (REGISTRAR, VERIFIER, ANCHOR_WRITER)
- **UUPS Upgradeable** — Future-proof contract architecture

---

## Project Structure

```
tlh/
├── contracts/           # Solidity smart contracts (Foundry)
│   ├── src/            # Contract source files
│   ├── test/           # Foundry tests (173 passing)
│   ├── script/         # Deployment scripts
│   └── docs/           # Architecture & delivery docs
├── frontend/           # Next.js 16 dashboard
│   └── src/app/        # App Router pages
├── prover-api/         # Express.js GMC lookup & attestation service
├── chainlink-node/     # Chainlink Node + External Adapter
│   ├── config/         # Node configuration
│   ├── external-adapter/  # Custom EA for attestation submission
│   └── jobs/           # Job specifications
└── private-chain/      # Polygon Edge IBFT 2.0 (4 validators)
```

---

## Smart Contracts

Deployed on **Sepolia (Chain ID: 11155111)**:

| Contract | Address | Purpose |
|----------|---------|---------|
| DIDRegistry | `0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a` | Decentralized identifier storage |
| VCHashAnchors | `0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68` | VC hash anchoring |
| CredentialRegistry | `0xae4b71776fab8e431cee4874ad3a2a97588d89fb` | Credential status management |
| AttestationVerifier | `0xce863e465f21df87ad9f0a2af838fac1750f08d2` | Shared chain verifier |
| TrustAttestationVerifier | `0x2ad7540b14585ebfb3c86604d1927b40e2efa5db` | Trust chain verifier |
| TLHCCIPReceiver | `0x234Aec51d3977bA5174B068d2Daf15e5367C0bF0` | CCIP credential receiver |
| TLHCCIPSender | `0xB8238cA59c7479e16d888A86A533A3113886A260` | CCIP credential sender |

---

## Quick Start

### Prerequisites

- Node.js 18+
- Docker & Docker Compose
- Foundry (`curl -L https://foundry.paradigm.xyz | bash`)
- Sepolia ETH (for transactions)

### 1. Install Dependencies

```bash
# Frontend
cd frontend && npm install

# Prover API
cd prover-api && npm install

# External Adapter
cd chainlink-node/external-adapter && npm install

# Smart Contracts
cd contracts && forge install
```

### 2. Configure Environment

```bash
# Copy example env files
cp prover-api/.env.example prover-api/.env
cp chainlink-node/.env.example chainlink-node/.env

# Edit with your values:
# - PRIVATE_KEY (deployer wallet)
# - RPC_URL (Sepolia/Alchemy/Infura)
# - PROVER_PRIVATE_KEY (attestation signer)
```

### 3. Run Development Servers

```bash
# Terminal 1: Prover API
cd prover-api && npm run dev
# → http://localhost:8787

# Terminal 2: Frontend
cd frontend && npm run dev
# → http://localhost:3000
```

### 4. Run Tests

```bash
# Smart contract tests (173 tests)
cd contracts && forge test -vvv

# Frontend build check
cd frontend && npm run build
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](contracts/docs/ARCHITECTURE.md) | System design and contract hierarchy |
| [MVP Scope](contracts/docs/delivery/01-mvp-scope-definition.md) | Feature scope and requirements |
| [QA Report](contracts/docs/delivery/03-formal-qa-report.md) | Test results and coverage |
| [Security Assessment](contracts/docs/delivery/04-security-and-compliance-assessment.md) | Security audit findings |
| [Deployment Guide](contracts/docs/delivery/05-deployment-and-handover-pack.md) | Production deployment steps |
| [Private Chain Ops](contracts/docs/delivery/06-private-chain-architecture-and-ops.md) | Polygon Edge operations |
| [CCIP Integration](contracts/docs/delivery/07-ccip-integration-spec.md) | Cross-chain credential sharing |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Smart Contracts | Solidity 0.8.28, OpenZeppelin 5.x, Foundry |
| Frontend | Next.js 16, React 19, Tailwind CSS 4, wagmi/viem |
| Backend | Express.js 5, TypeScript, Zod validation |
| Blockchain | Ethereum Sepolia, Polygon Edge IBFT 2.0 |
| Oracle | Chainlink DECO, CCIP |
| Infrastructure | Docker, GitHub Actions |

---

## API Endpoints

### Prover API (`localhost:8787`)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Service health check |
| `/gmc/lookup?gmcNumber=123456` | GET | GMC register lookup |
| `/gmc/doctors` | GET | List demo doctors |
| `/deco/attestation` | GET | Generate DECO attestation |
| `/deco/verify` | GET | Verify attestation signature |

### Frontend (`localhost:3000`)

| Route | Description |
|-------|-------------|
| `/` | Dashboard with system status |
| `/verify` | 3-step credential verification pipeline |
| `/explorer` | DID resolution explorer |
| `/credentials` | Credential registry browser |
| `/attestations` | On-chain attestation viewer |
| `/docs` | API documentation |

---

## Security

- **No PII on-chain** — Only cryptographic hashes are stored
- **ECDSA secp256k1** — Standard Ethereum signature scheme
- **Replay protection** — Nonce-based attestation uniqueness
- **Role-based access** — OpenZeppelin AccessControl
- **UUPS upgradeable** — Secure upgrade pattern with UPGRADER_ROLE
- **CSP headers** — Content Security Policy on frontend

See [Security Assessment](contracts/docs/delivery/04-security-and-compliance-assessment.md) for full audit.

---

## License

Copyright 2026 Pixelette Technologies. All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or use is strictly prohibited.

---

## Contact

**Pixelette Technologies**
[pixelette.tech](https://pixelette.tech)

For technical inquiries regarding this project, contact the delivery team.
