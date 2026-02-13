# Trust Layer Health (TLH) Project Analysis

**Date:** February 12, 2026
**Repository:** [pixelette-technologies/tlh](https://github.com/pixelette-technologies/tlh)
**Client:** Chad Donahue (Trust Layer Health)
**Prepared by:** Pixelette Technologies

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Repository Overview](#repository-overview)
3. [Project Vision](#project-vision)
4. [Technical Deep-Dive](#technical-deep-dive)
5. [SLA vs Delivery Analysis](#sla-vs-delivery-analysis)
6. [Milestone Assessment](#milestone-assessment)
7. [Deviation Analysis](#deviation-analysis)
8. [Cost & Timeline Justification](#cost--timeline-justification)
9. [Key Technical Concepts](#key-technical-concepts)
10. [Recommendations](#recommendations)

---

## Executive Summary

### Key Findings

| Metric | Value |
|--------|-------|
| **Repository Status** | Private, accessible |
| **Code Quality** | Good — well-engineered |
| **SLA Alignment** | What was built aligns with SLA |
| **Completeness** | ~20% of full technical scope |
| **Milestone Progress** | M1: 100%, M2: ~80% |
| **Overall Deviation** | ~0-5% (built correctly, but incomplete) |

### Critical Gaps

1. **Private Chain** — Not implemented (using public Sepolia)
2. **CCIP Gateway** — Not implemented
3. **Frontend UI** — Not implemented
4. **DID/VC Strategy** — Not implemented
5. **Smart Contracts** — Not implemented (only self-transfer txs)
6. **QA/Testing** — Zero tests

---

## Repository Overview

### Access & Structure

| Property | Value |
|----------|-------|
| **Repository** | pixelette-technologies/tlh |
| **Visibility** | Private |
| **Owner** | Pixelette Technologies (Organization) |
| **Default Branch** | main |
| **License** | MIT |
| **Last Push** | December 22, 2025 |

### Directory Structure

```
tlh/
├── chainlink-node/           # Chainlink Node Docker setup
│   ├── config/               # Node configuration files
│   ├── external-adapter/     # Bridge to Prover API
│   └── jobs/                 # Job specifications
├── cre-workflow/             # Chainlink Runtime Environment workflows
│   └── tls-cre-poc/
│       ├── deco-verification-workflow/
│       └── physician-cred-workflow/
├── deco-scripts/             # Standalone verification scripts
├── prover-api/               # DECO verification backend
│   └── src/server.ts         # Main API server (530 lines)
├── DEMO-README.md            # Architecture documentation
├── START-HERE.md             # Setup guide
├── dummy-data.csv            # GMC test data
├── json-encoded-attestation.json
└── decoded-attested-data.json
```

### Commit History

| Date | Commit | Description |
|------|--------|-------------|
| 7 weeks ago | `ff97f18` | Initial commit (Salman) |
| 7 weeks ago | `d5d6881` | First commit (Lukman) |
| 3 weeks ago | `68fcca5` | Draft implementation |
| 5 days ago | `243737d` | Added documentation |
| 5 days ago | `051ec3f` | Removed Claude-generated files |

### Current Collaborators

- `lukmaan-k` — admin
- `temurkhan13` — admin

---

## Project Vision

### The Problem

Healthcare credential verification is:
- **Slow** — Takes 4-6 weeks
- **Expensive** — Manual staff time
- **Fraud-prone** — Fake documents possible
- **Repetitive** — Must verify for every employer
- **No audit trail** — Hard to track

### The Solution

**One-time verification, permanent proof, instant trust.**

```
Doctor verifies ONCE
        ↓
Proof stored on blockchain (permanent, tamper-proof)
        ↓
ANY hospital can instantly verify
        ↓
Hired in minutes, not weeks
```

### Intended Architecture (Per SLA)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        TRUST LAYER HEALTH                                │
└─────────────────────────────────────────────────────────────────────────┘

    DOCTOR                                              VERIFIER
         │                                                   │
         ▼                                                   │
┌─────────────────┐                                          │
│  PERSONA        │  Identity verification                   │
│  (ID check)     │  - Passport/ID scan                      │
│                 │  - Selfie match                          │
└────────┬────────┘                                          │
         │                                                   │
         ▼                                                   │
┌─────────────────┐                                          │
│  GMC REGISTER   │  Credential verification                 │
│  (UK doctors)   │  - License status                        │
└────────┬────────┘                                          │
         │                                                   │
         ▼                                                   │
┌─────────────────┐                                          │
│  CHAINLINK      │  Oracle network                          │
│  DECO           │  - Creates cryptographic attestation     │
└────────┬────────┘                                          │
         │                                                   │
         ▼                                                   │
┌─────────────────┐     ┌─────────────────┐                  │
│  PRIVATE CHAIN  │────▶│  CCIP GATEWAY   │                  │
│  (Hospital's    │     │  (Cross-chain   │                  │
│   network)      │     │   bridge)       │                  │
└─────────────────┘     └────────┬────────┘                  │
                                 │                           │
                                 ▼                           │
                        ┌─────────────────┐                  │
                        │  PUBLIC CHAIN   │◀─────────────────┘
                        │  (Anchor)       │  Verification query
                        └─────────────────┘
```

### Stakeholder Benefits

| Stakeholder | Benefit |
|-------------|---------|
| **Doctors** | Verify once, carry proof forever |
| **Hospitals** | Instant hiring, reduced liability |
| **Patients** | Confidence their doctor is real |
| **Regulators** | Complete audit trail |
| **Insurance** | Lower malpractice risk |

---

## Technical Deep-Dive

### What Was Built

#### 1. Prover API (`prover-api/src/server.ts`)

**Purpose:** Verifies DECO attestations and provides GMC lookup

**Endpoints:**
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/deco/verify` | GET | Verify DECO attestation from files |
| `/deco/verify` | POST | Verify attestation from request body |
| `/deco/attestation` | GET | Return raw attestation |
| `/gmc/lookup` | GET/POST | Lookup doctor in GMC register |
| `/doctor/register` | POST | Register doctor commitment |
| `/credential/latest/:id` | GET | Get latest credential |
| `/health` | GET | Health check |

**Key Features:**
- Real ECDSA secp256k1 signature verification using `@noble/curves`
- Keccak256 hashing
- GMC CSV data lookup
- Doctor commitment generation

#### 2. External Adapter (`chainlink-node/external-adapter/`)

**Purpose:** Bridge between Chainlink Node and Prover API

**Flow:**
```
Chainlink Node → External Adapter → Prover API → Blockchain TX
```

**What it does:**
1. Receives job request from Chainlink
2. Calls Prover API `/deco/verify`
3. Encodes result as hex ("PASS|proofId")
4. Sends self-transfer transaction to Sepolia
5. Returns txHash to Chainlink

#### 3. Chainlink Node Setup (`chainlink-node/`)

**Components:**
- Docker Compose configuration
- PostgreSQL database
- Node configuration (`config.toml`, `secrets.toml`)
- Job specifications (webhook-based)

**Credentials:** Configured via `chainlink-node/.env` — see `.env.example` for template.

#### 4. CRE Workflows (`cre-workflow/`)

**Two workflows:**
1. `deco-verification-workflow` — Generic DECO verification
2. `physician-cred-workflow` — Physician-specific verification

**Note:** Contains `TODO!!!!!!` for production authorization keys.

#### 5. Documentation

**Excellent documentation including:**
- `DEMO-README.md` — 554 lines, architecture diagrams
- `START-HERE.md` — 461 lines, step-by-step setup
- `chainlink-node/README.md` — Full node setup guide

### What Was NOT Built

| Component | Status |
|-----------|--------|
| Private Chain (Besu/Polygon Edge) | Not implemented |
| CCIP Gateway | Not implemented |
| Smart Contracts | Not implemented (only self-transfer) |
| Frontend UI | Not implemented |
| DID/VC (SpruceID) | Not implemented |
| Chainlink Functions | Not used |
| ZK Workflows | Not implemented |
| Chainlink Automation | Only webhooks (manual) |
| Test Suite | Zero tests |
| CI/CD Pipeline | Not implemented |
| Security Assessment | Not done |

---

## SLA vs Delivery Analysis

### SLA Deliverables (Section 3.1)

| # | SLA Deliverable | Built? | Notes |
|---|-----------------|--------|-------|
| 1 | MVP Scope Definition Document | ❌ | Not found |
| 2 | Technical Blueprint and Architecture Design | ⚠️ | DEMO-README only |
| 3 | Shared Anchor Chain and Private Trust Chain | ❌ | Only Sepolia |
| 4 | Backend & Private Chain Implementation | ⚠️ | Backend only |
| 5 | Frontend Demo Interface | ❌ | Not built |
| 6 | DID and VC Strategy Implementation | ❌ | Not built |
| 7 | Chainlink Integration Plan (Functions, CCIP, ZK) | ⚠️ | DECO only |
| 8 | QA, DevOps, and Security Assessment | ❌ | Not done |
| 9 | VC Hash Anchors | ❌ | Not built |
| 10 | Project Roadmap and Sprint Plan | ❌ | Not found |
| 11 | Final Deployment and Handover Documentation | ⚠️ | Setup docs only |

### Documentation vs SLA Comparison

| SLA Component | In Lukman's Docs? | In Code? |
|---------------|-------------------|----------|
| Private Chain | ❌ Not mentioned | ❌ Not built |
| CCIP Gateway | ❌ Not mentioned | ❌ Not built |
| Frontend UI | ❌ Not mentioned | ❌ Not built |
| Chainlink Automation | ❌ Not mentioned | ❌ Not built |
| DID/VC | ❌ Not mentioned | ❌ Not built |

**Conclusion:** Lukman's documentation describes a DECO verification demo, not the full SLA scope.

---

## Milestone Assessment

### Milestone 1 — Project Initiation (25%)

**Due:** Upon Project Initiation
**Value:** £13,437.50

| Deliverable | Status |
|-------------|--------|
| Project setup | ✅ Complete |
| Initial project initialization | ✅ Complete |
| Kick-off workshop | ✅ Assumed complete |
| Stakeholder alignment | ✅ Assumed complete |
| Initiation of backend & blockchain foundations | ✅ Complete |

**M1 Status: ✅ 100% COMPLETE**

---

### Milestone 2 — Core Backend & Blockchain (25%)

**Due:** Upon completion of Phase 2
**Value:** £13,437.50

| Deliverable | Status |
|-------------|--------|
| Backend setup | ✅ Complete (Prover API) |
| **Private chain setup** | ❌ **NOT COMPLETE** (Sepolia is public) |
| Chainlink node setup | ✅ Complete |
| Dummy API development | ✅ Complete (GMC lookup) |
| Credential schema definitions | ✅ Complete (TypeScript types) |

**M2 Status: ⚠️ 80% COMPLETE (4/5 items)**

**Critical Gap:** "Private chain setup" explicitly required but not delivered.

---

### Milestone 3 — Frontend & Chainlink/CCIP (25%)

**Due:** Upon completion of Phase 3
**Value:** £13,437.50

| Deliverable | Status |
|-------------|--------|
| Frontend demo UI | ❌ Not built |
| Integration with private chains | ❌ Not built |
| CCIP gateway setup | ❌ Not built |
| Attestation envelopes | ✅ Complete |
| Chainlink automation jobs | ❌ Only webhooks |

**M3 Status: ❌ ~20% COMPLETE (1/5 items)**

---

### Milestone 4 — QA, DevOps, Security (25%)

**Due:** Upon completion of Phase 4
**Value:** £13,437.50

| Deliverable | Status |
|-------------|--------|
| Security & compliance assessment | ❌ Not done |
| Full QA | ❌ No tests |
| Roadmap finalisation | ❌ Not done |
| Sprint handover | ❌ Not applicable |
| Documentation and system outputs | ⚠️ Setup docs only |

**M4 Status: ❌ ~10% COMPLETE**

---

### Milestone Summary

```
Milestone 1: ✅ COMPLETE     (100%)  ████████████████████
Milestone 2: ⚠️ PARTIAL      ( 80%)  ████████████████░░░░
Milestone 3: ❌ NOT COMPLETE ( 20%)  ████░░░░░░░░░░░░░░░░
Milestone 4: ❌ NOT STARTED  ( 10%)  ██░░░░░░░░░░░░░░░░░░
```

---

## Deviation Analysis

### Key Question: Does What Was Built Deviate from SLA?

**Answer: No — ~0-5% deviation**

Everything Lukman built aligns with SLA requirements:

| What Was Built | SLA Reference | Deviation |
|----------------|---------------|-----------|
| Chainlink Node Setup | M2: "Chainlink node setup" | ✅ 0% |
| DECO Integration | Section 5: "Chainlink DECO" | ✅ 0% |
| Prover API (Backend) | M2: "Backend setup" | ✅ 0% |
| GMC Dummy API | M2: "Dummy API development" | ✅ 0% |
| Attestation Envelopes | M3: "Attestation envelopes" | ✅ 0% |
| Setup Documentation | M4: "Documentation" | ✅ 0% |

### The Distinction

| Term | Meaning | Assessment |
|------|---------|------------|
| **Deviation** | Building something different | ❌ No deviation |
| **Incompleteness** | Not building everything | ✅ Yes, incomplete |

**What was built is correct. It's just not everything.**

---

## Cost & Timeline Justification

### SLA Financial Terms

| Metric | Value |
|--------|-------|
| Total Project Value | £107,500 |
| Client Contribution | £53,750 (50%) |
| Pixelette Contribution | £53,750 (50%) |
| Timeline | 18 weeks |

### Effort Estimation (Full Scope)

| Component | Estimated Effort |
|-----------|------------------|
| Private Chain Setup | 1-2 weeks |
| CCIP Integration | 2-3 weeks |
| Smart Contracts | 2-3 weeks |
| Frontend Demo UI | 3-4 weeks |
| DID/VC Strategy | 2-3 weeks |
| Chainlink Node | 1 week |
| DECO Integration | 1-2 weeks |
| Backend APIs | 2-3 weeks |
| QA/Testing | 2 weeks |
| Security Assessment | 1 week |
| Documentation | 1 week |
| DevOps | 1 week |
| **Total** | **19-26 weeks** |

### Cost Analysis

```
£107,500 / 18 weeks = £5,972/week

If 2 developers:
£5,972 / 2 = £2,986/week/dev = ~£597/day/dev

UK Senior Blockchain Developer Rates:
├── Junior: £300-400/day
├── Mid: £400-550/day
├── Senior: £550-800/day
└── Specialist: £700-1000/day

Verdict: £597/day = MID-LEVEL rate — FAIR
```

### Assessment

| Question | Answer |
|----------|--------|
| Is 18 weeks justified? | ✅ Yes — scope is substantial |
| Is £107,500 justified? | ✅ Yes — fair for blockchain MVP |
| Is client's £53,750 justified? | ✅ Yes — 50% discount via HSE |
| Is timeline achievable? | ⚠️ Tight but doable |

**The SLA is well-priced. The issue is delivery, not the contract.**

---

## Key Technical Concepts

### What is Chainlink DECO?

**DECO = Decentralized Oracle for Confidential Data**

DECO proves facts about web data without revealing the data itself.

```
How DECO Works:
─────────────────────────────────────────────────────────────────

1. TLS Session Capture
   - DECO witnesses the TLS session between user and website
   - Cryptographically proves data came from real server

2. Predicate Evaluation
   - Evaluates yes/no questions on the data
   - "Is registration status = 'Active'?" → TRUE

3. Attestation Creation
   - Creates signed proof with oracle key
   - Reveals: PASS/FAIL, verification type, timestamp
   - Hides: Name, DOB, actual response data

4. Verification
   - Anyone can verify signature is valid
   - No personal data exposed
```

### DECO vs ZKP

| Aspect | ZKP | DECO |
|--------|-----|------|
| What it proves | "I computed correctly" | "Data came from website X" |
| Source of truth | Mathematical computation | External website (TLS) |
| Core tech | Circuits (SNARKs/STARKs) | TLS witnessing |
| Use case | Computation privacy | Web data privacy |

**They're related but different. DECO proves data authenticity; ZKP proves computation.**

### Private Chain Options

| Option | Difficulty | Time to MVP |
|--------|------------|-------------|
| Hyperledger Fabric | 🔴 Hard | 2-4 weeks |
| Hyperledger Besu | 🟡 Medium | 3-5 days |
| Polygon Edge | 🟢 Easy | 1-2 days |
| Managed Service | 🟢 Easiest | Hours |

**Recommendation:** Polygon Edge for MVP, migrate to Besu if NHS requires.

### Multi-Chain Compatibility

Both Besu and Polygon Edge are EVM-compatible. CCIP handles cross-chain communication.

```
Hospital A (Polygon Edge)  ←─── CCIP ───→  Hospital B (Besu)
                                 │
                                 ▼
                          Anchor Chain
                           (Sepolia)
```

**Hospitals can choose their preferred chain. CCIP bridges them.**

---

## Recommendations

### Immediate Actions

1. **Clarify M2 with Client**
   - Does "private chain setup" include Sepolia?
   - Get written confirmation on interpretation

2. **Document Scope Gap**
   - Create formal change request if scope changed
   - Get client sign-off on modified scope

3. **Prioritize Remaining Work**
   - Private chain setup (Polygon Edge)
   - Smart contracts (Solidity)
   - CCIP integration
   - Frontend UI

### Technical Roadmap to Complete

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 🔴 P0 | Smart Contract | 2-3 weeks | Critical |
| 🔴 P0 | Private Chain | 1-2 weeks | Critical |
| 🔴 P0 | CCIP Integration | 2-3 weeks | Critical |
| 🟡 P1 | Frontend UI | 3-4 weeks | High |
| 🟡 P1 | DID/VC Strategy | 2-3 weeks | High |
| 🟢 P2 | Test Suite | 2 weeks | Medium |
| 🟢 P2 | Security Review | 1 week | Medium |

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Client disputes M2 | Medium | High | Get written scope clarification |
| Timeline overrun | High | Medium | Reprioritize, add resources |
| Technical complexity | Medium | Medium | Use Polygon Edge (simpler) |
| NHS requirements | Unknown | High | Early engagement with NHS |

---

## Appendix

### A. Technology Stack

- **Backend:** Node.js, Express, TypeScript
- **Blockchain:** Sepolia (current), Besu/Polygon Edge (planned)
- **Chainlink:** Node v2.x, DECO, CRE SDK
- **Crypto:** @noble/curves, viem, ethers.js
- **Database:** PostgreSQL (Chainlink), JSON files (Prover API)
- **Infrastructure:** Docker, Docker Compose

### B. Repository Files

| File | Lines | Purpose |
|------|-------|---------|
| `prover-api/src/server.ts` | 530 | Main verification API |
| `chainlink-node/external-adapter/src/index.ts` | 149 | Chainlink bridge |
| `DEMO-README.md` | 554 | Architecture docs |
| `START-HERE.md` | 461 | Setup guide |
| `deco-scripts/src/verify-and-submit.ts` | 263 | Standalone script |

### C. API Endpoints Summary

| Service | Port | Endpoints |
|---------|------|-----------|
| Chainlink Node | 6688 | Web UI, API |
| Prover API | 8787 | /deco/verify, /gmc/lookup |
| External Adapter | 8788 | POST / |

### D. SLA Payment Schedule

| Milestone | Amount | Status |
|-----------|--------|--------|
| M1 | £13,437.50 | ✅ Claimable |
| M2 | £13,437.50 | ⚠️ Partial (no private chain) |
| M3 | £13,437.50 | ❌ Not claimable |
| M4 | £13,437.50 | ❌ Not claimable |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-02-12 | Claude (Opus 4.5) | Initial analysis |

---

*This document was generated during a code review session analyzing the TLH repository against the signed SLA.*
