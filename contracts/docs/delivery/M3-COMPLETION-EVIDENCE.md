# TLH Milestone 3 Completion Evidence

- **Document Owner**: TLH Delivery Team
- **Date**: February 18, 2026
- **Version**: v1.0
- **Status**: Ready for Client Review

---

## Executive Summary

**Milestone 3 is COMPLETE and FULLY FUNCTIONAL.**

All integration components are operational and have been verified with live transactions on Sepolia testnet. This document provides comprehensive evidence of completion.

---

## M3 Deliverables Checklist

| # | Deliverable | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Frontend Demo Interface | ✅ COMPLETE | Running on port 3001, all pages functional |
| 2 | CCIP Integration Spec | ✅ COMPLETE | `07-ccip-integration-spec.md` |
| 3 | Chainlink Functions/Automation Runbook | ✅ COMPLETE | `08-chainlink-functions-automation-runbook.md` |
| 4 | Prover API Integration | ✅ COMPLETE | Running on port 8787, DECO verification working |
| 5 | External Adapter Integration | ✅ COMPLETE | Running on port 8788, on-chain tx working |
| 6 | End-to-End Pipeline | ✅ COMPLETE | Verified with 4 successful Sepolia transactions |
| 7 | GMC Lookup Integration | ✅ COMPLETE | Demo data loaded, lookup functional |

---

## Live Verification Results (2026-02-18)

### 1. Service Health Check

| Service | Port | Status | Response |
|---------|------|--------|----------|
| Prover API | 8787 | ✅ UP | `{"ok":true}` |
| External Adapter | 8788 | ✅ UP | `{"status":"ok","proverApiConfigured":true,"rpcConfigured":true}` |
| Frontend | 3001 | ✅ UP | HTTP 200 |

### 2. DECO Verification Flow

**Request**: `GET http://localhost:8787/deco/verify`

**Response**:
```json
{
  "result": "PASS",
  "reason": "All checks passed",
  "proofId": "0xec5d5d9fba2bef6d",
  "dataRetrievalTime": "2026-01-19T14:43:48Z",
  "timestamp": "2026-02-18T11:42:09.906Z"
}
```

**Verification**: ✅ PASS

### 3. GMC Lookup Flow

**Request**: `GET http://localhost:8787/gmc/lookup?surname=Adfcds&givenName=Azhar`

**Response**:
```json
{
  "found": true,
  "gmcRefNo": "4333333",
  "surname": "Adfcds",
  "givenName": "Azhar",
  "registrationStatus": "Registered with Licence",
  "revalidationStatus": "This doctor is subject to revalidation",
  "qualification": "MB BS",
  "yearOfQualification": "1997",
  "placeOfQualification": "University of London",
  "designatedBody": "NHS England - Central Midlands"
}
```

**Verification**: ✅ FOUND

### 4. On-Chain Transaction Evidence

**Successful Sepolia Transactions (2026-02-18)**:

| # | Transaction Hash | Status | Etherscan Link |
|---|-----------------|--------|----------------|
| 1 | `0x2f945de2f305f39d8b9069531ce98d4c444a272d392bdbdefce790c652920b18` | ✅ Confirmed | [View](https://sepolia.etherscan.io/tx/0x2f945de2f305f39d8b9069531ce98d4c444a272d392bdbdefce790c652920b18) |
| 2 | `0xa8cc5561a6acb18fdea960f2946a219ad6d6831eebf5648ca378ba790fd78518` | ✅ Confirmed | [View](https://sepolia.etherscan.io/tx/0xa8cc5561a6acb18fdea960f2946a219ad6d6831eebf5648ca378ba790fd78518) |
| 3 | `0x3f0e1f2cbf0920e216b1d23a92faf8ab01dd4ce80e9bfc6ddf2e793830f57e2e` | ✅ Confirmed | [View](https://sepolia.etherscan.io/tx/0x3f0e1f2cbf0920e216b1d23a92faf8ab01dd4ce80e9bfc6ddf2e793830f57e2e) |
| 4 | `0x428b4084b4fb97e1a93659bb08d620316a6fadbcc7b36badcf8ed46965690fd6` | ✅ Confirmed | [View](https://sepolia.etherscan.io/tx/0x428b4084b4fb97e1a93659bb08d620316a6fadbcc7b36badcf8ed46965690fd6) |

**Transaction Details** (from RPC receipt):
- Chain ID: 11155111 (Sepolia)
- Status: `0x1` (Success)
- From: `0x3b50966a8b71f277e90e14cdc31455f6af3977e6` (Admin wallet)

### 5. Frontend API Routes

| Route | Method | Status | Purpose |
|-------|--------|--------|---------|
| `/api/pipeline` | POST | ✅ Working | Full verification + on-chain submission |
| `/api/verify` | GET | ✅ Working | DECO verification only |
| `/api/gmc` | GET | ✅ Working | GMC doctor lookup |

---

## Deployed Contract Addresses (Sepolia)

| Contract | Proxy Address | Implementation Address |
|----------|---------------|----------------------|
| DIDRegistry | `0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a` | `0xdeecd6a976d5999315dcf0cf8e7fa0e6ea887cd6` |
| VCHashAnchors | `0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68` | `0x3b7803ba081228ea98626be219755b0295267013` |
| CredentialRegistry | `0xae4b71776fab8e431cee4874ad3a2a97588d89fb` | `0x94de2311e67abd4332c358b9c3a37e231f298249` |
| TrustAttestationVerifier | `0x2ad7540b14585ebfb3c86604d1927b40e2efa5db` | `0x893aad8b32e77845b2485e033c7031e31c13ec9b` |
| AttestationVerifier | `0xce863e465f21df87ad9f0a2af838fac1750f08d2` | `0x2ae518d86774c814a73ca03464b355a3a228ac8d` |

**Admin Wallet**: `0x3B50966A8B71f277e90e14cdC31455F6Af3977e6`
**Balance**: 0.39+ ETH (sufficient for operations)

---

## Test Suite Results

### Solidity Contract Tests
- **Command**: `forge test --skip test/ccip/** --skip src/ccip/**`
- **Result**: 134 tests passed, 0 failed, 0 skipped
- **Coverage**: Unit tests + Fork state tests + Fork behavior tests

### Frontend Build
- **Command**: `npm run build`
- **Result**: Success
- **Routes Generated**: `/`, `/attestations`, `/credentials`, `/did`, `/verify`

### Frontend Lint
- **Command**: `npm run lint`
- **Result**: 0 warnings, 0 errors

---

## Integration Architecture (Verified Working)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VERIFIED INTEGRATION FLOW                        │
└─────────────────────────────────────────────────────────────────────┘

  Frontend (3001)
       │
       │ POST /api/pipeline
       ▼
  ┌─────────────────┐
  │ API Route Proxy │ ← Server-side auth (tokens not exposed)
  │ Next.js         │
  └────────┬────────┘
           │
           │ Bearer Token Auth
           ▼
  ┌─────────────────┐     ┌─────────────────┐
  │ External Adapter│────►│ Prover API      │
  │ (8788)          │     │ (8787)          │
  │                 │◄────│                 │
  │ • Sign tx       │     │ • DECO verify   │
  │ • Nonce mgmt    │     │ • GMC lookup    │
  │ • Submit RPC    │     │ • Signature     │
  └────────┬────────┘     └─────────────────┘
           │
           │ Signed Transaction
           ▼
  ┌─────────────────────────────────────────┐
  │         SEPOLIA (Chain 11155111)         │
  │                                         │
  │  DIDRegistry ◄─── AttestationVerifier   │
  │  VCHashAnchors ◄─┘                      │
  │                                         │
  │  CredentialRegistry ◄── TrustAttVerifier│
  └─────────────────────────────────────────┘
```

---

## Demo Script for Client

### Prerequisites
1. All services running (Prover API, External Adapter, Frontend)
2. Browser open to http://localhost:3001

### Demo Steps

**Step 1: Dashboard Overview**
- Navigate to `/` (Dashboard)
- Show: System status (all green), deployed contracts, network info

**Step 2: Load Attestation**
- Navigate to `/verify`
- Click "Load Attestation"
- Show: DECO signature data, public key, attestation scheme

**Step 3: Verify Attestation**
- Click "Verify Attestation"
- Show: PASS result, proof ID, timestamp

**Step 4: GMC Lookup**
- Select "Azhar Adfcds" from dropdown
- Click "Lookup"
- Show: GMC Ref, Registration Status, Qualification, Designated Body

**Step 5: Submit On-Chain**
- Click "Submit to Sepolia"
- Wait for transaction confirmation
- Show: Transaction hash, click Etherscan link
- Demonstrate: Transaction confirmed on Sepolia explorer

---

## Security Hardening Applied (2026-02-18)

| Component | Security Measure | Status |
|-----------|-----------------|--------|
| External Adapter | CORS restriction | ✅ Applied |
| External Adapter | Rate limiting | ✅ Applied |
| External Adapter | Bearer token auth | ✅ Applied |
| External Adapter | Nonce management | ✅ Applied |
| Prover API | Input validation (Zod) | ✅ Applied |
| Prover API | Rate limiting | ✅ Applied |
| Frontend | CSP headers | ✅ Applied |
| Frontend | Server-side auth tokens | ✅ Applied |
| Frontend | API route proxies | ✅ Applied |

---

## Documentation Delivered

| Document | Path | Status |
|----------|------|--------|
| MVP Scope Definition | `01-mvp-scope-definition.md` | ✅ Complete |
| Roadmap and Sprint Plan | `02-roadmap-and-sprint-plan.md` | ✅ Complete |
| Formal QA Report | `03-formal-qa-report.md` | ✅ Complete |
| Security Assessment | `04-security-and-compliance-assessment.md` | ✅ Complete |
| Deployment Handover | `05-deployment-and-handover-pack.md` | ✅ Complete |
| Private Chain Ops | `06-private-chain-architecture-and-ops.md` | ✅ Complete |
| CCIP Integration Spec | `07-ccip-integration-spec.md` | ✅ Complete |
| Automation Runbook | `08-chainlink-functions-automation-runbook.md` | ✅ Complete |
| SLA Traceability | `annex-a-sla-traceability-matrix.md` | ✅ Complete |
| Test Evidence | `annex-b-test-and-deployment-evidence.md` | ✅ Complete |

---

## Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Technical Lead | __________________ | __________________ | __________ |
| Delivery Manager | __________________ | __________________ | __________ |
| Client Representative | __________________ | __________________ | __________ |

---

## Appendix: Verification Commands

```bash
# Service health check
curl http://localhost:8787/health
curl http://localhost:8788/health
curl http://localhost:3001/

# DECO verification
curl http://localhost:8787/deco/verify

# GMC lookup
curl "http://localhost:8787/gmc/lookup?surname=Adfcds&givenName=Azhar"

# Full pipeline (on-chain submission)
curl -X POST http://localhost:8788/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tlh-dev-external-adapter-token-2026" \
  -d '{"id": "test", "data": {}}'

# Frontend pipeline
curl -X POST http://localhost:3001/api/pipeline \
  -H "Content-Type: application/json" \
  -d '{}'
```
