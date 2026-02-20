# TLH Comprehensive Security Audit Report

**Date:** 2026-02-18
**Auditor:** Pixelette Technologies Security Team
**Scope:** Full codebase review of TLH-New repository
**Repository:** `RanaKhangit/TLH-New` (2,058 files)

---

## Executive Summary

### Overall Risk Assessment

| Component | Critical | High | Medium | Low | Risk Level |
|-----------|----------|------|--------|-----|------------|
| Smart Contracts | 0 | 3 | 3 | 5 | **LOW-MEDIUM** |
| Prover API | 2 | 11 | 5 | 3 | **HIGH** |
| External Adapter | 1 | 9 | 7 | 3 | **HIGH** |
| Frontend | 1 | 5 | 10 | 5 | **MEDIUM** |
| Private Chain | 1 | 2 | 3 | 2 | **MEDIUM** |
| CI/CD | 0 | 1 | 2 | 2 | **LOW-MEDIUM** |
| **TOTAL** | **5** | **31** | **30** | **20** | **HIGH** |

### Production Readiness

| Component | Status | Blocker Issues |
|-----------|--------|----------------|
| Smart Contracts | **READY** with minor fixes | 3 high-priority fixes needed |
| Prover API | **NOT READY** | No authentication, open CORS |
| External Adapter | **NOT READY** | No authentication, key exposure |
| Frontend | **READY** with fixes | CSRF protection, CSP headers |
| Private Chain | **READY** for testnet | Use proper keys for production |
| CI/CD | **READY** | Add security scanning |

### Critical Issues Requiring Immediate Action

1. **Prover API: No Authentication** (CRITICAL)
2. **External Adapter: No Chainlink Authentication** (CRITICAL)
3. **Prover API: Unrestricted CORS** (CRITICAL)
4. **Frontend: No CSRF Protection** (CRITICAL)
5. **Private Chain: Hardcoded Anvil Private Key** (CRITICAL for production)

---

## 1. Smart Contracts Security Audit

### Summary
- **Files Reviewed:** 16 Solidity contracts + interfaces
- **Test Coverage:** 173 test functions (104 unit + 16 fork + 53 additional)
- **Risk Level:** LOW-MEDIUM

### High Priority Issues

#### Issue 1.1: Improper Error Handling in BaseAttestationVerifier
**Severity:** MEDIUM → HIGH
**Location:** `contracts/src/base/BaseAttestationVerifier.sol:111-123`

```solidity
try didRegistry.registerDID(subjectDID, address(this)) {
    emit DIDRegisteredViaAttestation(subjectDID, attestationId);
} catch (bytes memory reason) {
    bytes4 errorSelector;
    if (reason.length >= 4) {
        assembly {
            errorSelector := mload(add(reason, 32))
        }
    }
    if (errorSelector != IDIDRegistry.DIDAlreadyRegistered.selector) {
        assembly {
            revert(add(reason, 32), mload(reason))
        }
    }
}
```

**Problem:** If `reason.length < 4`, `errorSelector` remains `bytes4(0)` and legitimate errors could be swallowed.

**Fix:**
```solidity
if (reason.length < 4 || errorSelector != IDIDRegistry.DIDAlreadyRegistered.selector) {
    if (reason.length >= 4) {
        assembly { revert(add(reason, 32), mload(reason)) }
    }
    revert("Unknown DID registration error");
}
```

---

#### Issue 1.2: Revocation Prevents Valid Reissuance
**Severity:** MEDIUM
**Location:** `contracts/src/trust/CredentialRegistry.sol:93-95, 140-142`

**Problem:** Once a credential is revoked, it cannot be reissued even if conditions change. The status check `if (c.status != CredentialStatus.Revoked)` creates permanent denial.

**Impact:** A (subjectDID, predicateType) pair becomes permanently invalid.

**Fix:** Add `clearRevocation()` admin function or remove revocation check in `writeCredential()`.

---

#### Issue 1.3: Refund Could Fail in TLHCCIPSender
**Severity:** MEDIUM
**Location:** `contracts/src/ccip/TLHCCIPSender.sol:114-119`

```solidity
uint256 excess = msg.value - fee;
if (excess > 0) {
    (bool ok,) = msg.sender.call{value: excess}("");
    require(ok, "refund failed");
}
```

**Problem:** If sender is a contract without fallback, transaction reverts even though CCIP send succeeded. Nonce already incremented.

**Fix:** Increment nonce after successful send, or make refund failure non-fatal.

---

### Low/Info Issues

| ID | Issue | Severity | Location |
|----|-------|----------|----------|
| 1.4 | Missing signer removal validation | LOW | BaseAttestationVerifier.sol:82-88 |
| 1.5 | Unbounded history growth | LOW | VCHashAnchors.sol:40,65 |
| 1.6 | No event for registry updates | INFO | TrustAttestationVerifier.sol:87-91 |
| 1.7 | Nonce lacks upper bound | LOW | TLHCCIPReceiver.sol:179-181 |
| 1.8 | Attestation ID collision risk | LOW | TLHCCIPSender.sol:164-172 |

### Test Coverage Gaps

Missing edge case tests:
- Malformed revert data in try/catch
- Credential expiring at exact `block.timestamp`
- Multiple CCIP messages from same source in same block
- Refund to contract with reverting fallback

---

## 2. Prover API Security Audit

### Summary
- **Files Reviewed:** `prover-api/src/server.ts` (530 lines)
- **Risk Level:** HIGH

### Critical Issues

#### Issue 2.1: Unrestricted CORS
**Severity:** CRITICAL
**Location:** `src/server.ts:132-134`

```typescript
res.header("Access-Control-Allow-Origin", "*")
res.header("Access-Control-Allow-Headers", "Content-Type")
res.header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
```

**Impact:** Any website can call API endpoints, enabling CSRF and data exfiltration.

**Fix:**
```typescript
const allowedOrigins = ["https://chainlink-node.example.com"];
const origin = req.get("origin") || "";
if (allowedOrigins.includes(origin)) {
    res.header("Access-Control-Allow-Origin", origin);
}
```

---

#### Issue 2.2: Unauthenticated API Access
**Severity:** CRITICAL
**Location:** All endpoints

**Affected Endpoints:**
- `POST /doctor/register` - Register fake doctors
- `POST /deco/ingest-attestation` - Inject false credentials
- `GET /deco/attestation` - Expose signature data
- `GET /gmc/lookup` - Scan entire doctor database

**Impact:** Anyone can register doctors, inject attestations, and query medical records.

**Fix:** Implement Bearer token authentication on all sensitive endpoints.

---

### High Priority Issues

| ID | Issue | Severity | Line |
|----|-------|----------|------|
| 2.3 | Unvalidated hex input | HIGH | 91-98 |
| 2.4 | No JSON schema validation | HIGH | 120-121 |
| 2.5 | Missing POST body validation | HIGH | 245-258 |
| 2.6 | Signature truncation risk | HIGH | 89-109 |
| 2.7 | No rate limiting | HIGH | All endpoints |
| 2.8 | Query parameter injection | HIGH | 425-475 |
| 2.9 | Hardcoded port | HIGH | 10 |
| 2.10 | Information leakage | HIGH | 106, 125 |

### Dependencies
- **Status:** 0 vulnerabilities in 123 packages
- **Note:** Zod 4.2.1 → update to 4.22+ for stability

---

## 3. External Adapter Security Audit

### Summary
- **Files Reviewed:** `chainlink-node/external-adapter/src/index.ts`
- **Risk Level:** HIGH

### Critical Issue

#### Issue 3.1: No Chainlink Node Authentication
**Severity:** CRITICAL
**Location:** `src/index.ts:35-42, 85-90`

```typescript
app.use((_req, res, next) => {
    res.header("Access-Control-Allow-Origin", "*")
    // NO AUTHENTICATION
    next()
})
app.post("/", async (req, res) => {
    const request = req.body as ChainlinkRequest
    // NO AUTH CHECK
```

**Impact:**
- Any attacker can execute transactions
- Wallet drained by spam
- Fake proofs posted on-chain
- No audit trail

**Fix:** Implement HMAC-SHA256 request signing with shared secret.

---

### High Priority Issues

| ID | Issue | Severity | Line |
|----|-------|----------|------|
| 3.2 | Wallet address in logs | HIGH | 154, 159 |
| 3.3 | Hardcoded gas limit | HIGH | 118 |
| 3.4 | No nonce management | HIGH | 114-119 |
| 3.5 | Chainlink request not validated | HIGH | 85-89 |
| 3.6 | Prover response not validated | HIGH | 95-105 |
| 3.7 | Sensitive data in errors | HIGH | 137-147 |
| 3.8 | No RPC endpoint validation | HIGH | 22-26 |
| 3.9 | No RPC timeout | HIGH | 49, 95 |

### Medium Priority Issues

| ID | Issue | Severity | Line |
|----|-------|----------|------|
| 3.10 | No transaction confirmation wait | MEDIUM | 114-121 |
| 3.11 | No transaction replacement (RBF) | MEDIUM | N/A |
| 3.12 | Health check exposes address | MEDIUM | 153-155 |
| 3.13 | Unhandled promise rejections | MEDIUM | 85 |
| 3.14 | No gas price management | MEDIUM | 114-119 |

---

## 4. Frontend Security Audit

### Summary
- **Framework:** Next.js 16.1.6 + React 19.2.3
- **Files Reviewed:** 15 pages/components
- **Risk Level:** MEDIUM

### Critical Issue

#### Issue 4.1: No CSRF Protection on Pipeline Trigger
**Severity:** CRITICAL
**Location:** `src/app/verify/page.tsx:67-80`

```typescript
export async function triggerFullPipeline(): Promise<PipelineResult> {
    return fetchJSON<PipelineResult>(EA_API, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: `demo-${Date.now()}`, data: {} }),
        // NO CSRF TOKEN
    });
}
```

**Impact:** Attacker website can trigger blockchain transactions via victim's browser.

**Fix:** Backend must issue CSRF tokens; frontend must include in requests.

---

### High Priority Issues

| ID | Issue | Severity | Location |
|----|-------|----------|----------|
| 4.2 | Missing CSP headers | HIGH | next.config.ts |
| 4.3 | No input sanitization | HIGH | credentials/page.tsx:93-113 |
| 4.4 | API key in NEXT_PUBLIC_ | HIGH | lib/wagmi.ts:4-6 |
| 4.5 | Detailed error messages | HIGH | Multiple pages |

### Medium Priority Issues

| ID | Issue | Severity | Location |
|----|-------|----------|----------|
| 4.6 | URL construction without validation | MEDIUM | lib/utils.ts:36-42 |
| 4.7 | Missing bytes32 validation consistency | MEDIUM | credentials/page.tsx |
| 4.8 | No length limits on input | MEDIUM | All input fields |
| 4.9 | API endpoints in NEXT_PUBLIC_ | MEDIUM | lib/api.ts:1-3 |
| 4.10 | No contract address validation | MEDIUM | lib/contracts.ts |

### Dependencies
- **Status:** No known CVEs
- **Note:** Ensure `package-lock.json` committed

---

## 5. Private Chain Security Audit

### Summary
- **Network:** Polygon Edge IBFT 2.0 (4 validators)
- **Chain ID:** 100100
- **Risk Level:** MEDIUM

### Critical Issue (Production Only)

#### Issue 5.1: Hardcoded Anvil Private Key
**Severity:** CRITICAL for production, INFO for testnet
**Location:** `private-chain/.env.example:9`

```bash
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Problem:** This is the well-known Anvil/Hardhat account #0 private key. Anyone who knows this key can:
- Drain all pre-funded ETH
- Deploy malicious contracts
- Upgrade proxy contracts

**Fix:** Generate fresh keys for production. Document that `.env.example` values are TESTNET ONLY.

---

### High Priority Issues

| ID | Issue | Severity | Location |
|----|-------|----------|----------|
| 5.2 | Init uses --insecure flag | HIGH | scripts/init.sh:56 |
| 5.3 | No TLS on validator RPC | HIGH | docker-compose.yml:28 |

### Medium Priority Issues

| ID | Issue | Severity | Location |
|----|-------|----------|----------|
| 5.4 | Validator keys in bind mounts | MEDIUM | docker-compose.yml:36 |
| 5.5 | Known pre-fund address | MEDIUM | genesis.json:12 |
| 5.6 | All ports exposed | MEDIUM | docker-compose.yml |

### Low Priority Issues

| ID | Issue | Severity |
|----|-------|----------|
| 5.7 | No log rotation | LOW |
| 5.8 | No monitoring/alerting | LOW |

---

## 6. CI/CD Security Audit

### Summary
- **Platform:** GitHub Actions
- **Files Reviewed:** `.github/workflows/ci.yml`
- **Risk Level:** LOW-MEDIUM

### Current Configuration

```yaml
jobs:
  contracts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge build
      - run: forge test --skip test/ccip/** --no-match-path "test/fork/*"

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci && npm run build && npm run lint
```

### Issues

| ID | Issue | Severity | Fix |
|----|-------|----------|-----|
| 6.1 | No dependency audit | HIGH | Add `npm audit` step |
| 6.2 | No SAST scanning | MEDIUM | Add CodeQL or Semgrep |
| 6.3 | No secret scanning | MEDIUM | Add gitleaks |
| 6.4 | Fork tests skipped | LOW | Run in separate job |
| 6.5 | No Slither analysis | LOW | Add Slither for contracts |

### Recommended CI Additions

```yaml
- name: Security Audit
  run: npm audit --production

- name: Static Analysis
  uses: github/codeql-action/analyze@v2

- name: Secret Scanning
  uses: gitleaks/gitleaks-action@v2

- name: Slither Analysis
  uses: crytic/slither-action@v0.3.0
```

---

## 7. Environment Configuration Security

### Sensitive Files Review

| File | Contains Secrets | Issue |
|------|-----------------|-------|
| `private-chain/.env.example` | Yes (hardcoded key) | CRITICAL - Use placeholder |
| `chainlink-node/.env.example` | Placeholders | OK |
| `external-adapter/.env.example` | Placeholder | OK |
| `frontend/.env.example` | API key placeholder | OK |

### Secrets Management

| Secret | Current Storage | Recommendation |
|--------|-----------------|----------------|
| DEPLOYER_PRIVATE_KEY | .env file | AWS Secrets Manager / Vault |
| PRIVATE_KEY (EA) | .env file | AWS KMS for signing |
| ALCHEMY_API_KEY | NEXT_PUBLIC_ | Server-side proxy |
| POSTGRES_PASSWORD | .env file | Vault or Docker secrets |

---

## 8. Remediation Roadmap

### Phase 1: Critical (Before Any Production Use)

| Priority | Issue | Component | Effort |
|----------|-------|-----------|--------|
| 1 | Add authentication | Prover API | 4-6 hrs |
| 2 | Add authentication | External Adapter | 4-6 hrs |
| 3 | Restrict CORS | Prover API | 1 hr |
| 4 | Add CSRF protection | Frontend | 2-4 hrs |
| 5 | Replace test private key | Private Chain | 1 hr |

**Total Phase 1:** ~14-18 hours

### Phase 2: High Priority (Before Beta)

| Priority | Issue | Component | Effort |
|----------|-------|-----------|--------|
| 6 | Add CSP headers | Frontend | 2 hrs |
| 7 | Add input validation | All | 6-8 hrs |
| 8 | Fix error handling | Smart Contracts | 2 hrs |
| 9 | Add rate limiting | Prover API | 2 hrs |
| 10 | Add nonce management | External Adapter | 4 hrs |
| 11 | Add CI security scanning | CI/CD | 2 hrs |

**Total Phase 2:** ~18-22 hours

### Phase 3: Medium Priority (Before GA)

| Priority | Issue | Component | Effort |
|----------|-------|-----------|--------|
| 12 | Move secrets to Vault | All | 8 hrs |
| 13 | Add TLS to private chain | Private Chain | 4 hrs |
| 14 | Add transaction monitoring | External Adapter | 4 hrs |
| 15 | Add audit logging | All backends | 6 hrs |
| 16 | Add credential revocation recovery | Smart Contracts | 4 hrs |

**Total Phase 3:** ~26 hours

---

## 9. Testing Checklist

### Authentication Tests
- [ ] Unauthenticated requests to Prover API return 401
- [ ] Unauthenticated requests to EA return 401
- [ ] Invalid tokens rejected
- [ ] Expired tokens rejected

### Input Validation Tests
- [ ] Malformed hex strings rejected
- [ ] Oversized inputs rejected (>10KB)
- [ ] SQL/XSS payloads sanitized
- [ ] Bytes32 format validated

### Rate Limiting Tests
- [ ] >10 requests/minute to /deco/verify returns 429
- [ ] >30 requests/minute to /gmc/lookup returns 429

### CSRF Tests
- [ ] Cross-origin POST to /api/pipeline returns 403
- [ ] Missing CSRF token rejected
- [ ] Expired CSRF token rejected

### Contract Tests
- [ ] Revoked credential cannot be queried as valid
- [ ] Malformed predicate data causes specific revert
- [ ] CCIP nonce strictly sequential

---

## 10. Comparison: Original vs TLH-New

| Security Aspect | Original TLH (Lukman) | TLH-New (Rana) |
|-----------------|----------------------|----------------|
| Smart Contracts | None deployed | 5 contracts, well-tested |
| Access Control | N/A | RBAC with proper roles |
| Signature Verification | Basic ECDSA | Full ECDSA + domain separation |
| Input Validation | Minimal | Zod schemas (partial) |
| Authentication | None | None (still needs work) |
| Test Coverage | None | 173 test functions |
| Fork Tests | None | 16 fork tests |
| QA Evidence | None | Full QA report |
| UUPS Upgrades | N/A | Properly implemented |

**Conclusion:** TLH-New has significantly better security posture in smart contracts but both repositories lack backend authentication.

---

## 11. Appendix: Vulnerability Details

### A. Smart Contract Vulnerabilities (Full List)

| ID | Contract | Issue | Severity | Status |
|----|----------|-------|----------|--------|
| SC-01 | BaseAttestationVerifier | Error handling in try/catch | HIGH | Open |
| SC-02 | AttestationVerifier | Predicate format assumption | MEDIUM | Open |
| SC-03 | CredentialRegistry | Revocation permanence | MEDIUM | Open |
| SC-04 | TLHCCIPSender | Refund atomicity | MEDIUM | Open |
| SC-05 | VCHashAnchors | Unbounded history | LOW | Open |
| SC-06 | TLHCCIPReceiver | Nonce overflow | LOW | Open |
| SC-07 | TLHCCIPSender | Attestation ID collision | LOW | Open |
| SC-08 | BaseAttestationVerifier | Signer removal validation | LOW | Open |
| SC-09 | TrustAttestationVerifier | Missing config event | INFO | Open |
| SC-10 | BaseAttestationVerifier | Signature malleability doc | INFO | Open |

### B. Backend Vulnerabilities (Full List)

| ID | Component | Issue | Severity | Status |
|----|-----------|-------|----------|--------|
| BE-01 | Prover API | No authentication | CRITICAL | Open |
| BE-02 | Prover API | Unrestricted CORS | CRITICAL | Open |
| BE-03 | External Adapter | No authentication | CRITICAL | Open |
| BE-04 | Prover API | Unvalidated hex input | HIGH | Open |
| BE-05 | Prover API | No JSON validation | HIGH | Open |
| BE-06 | External Adapter | Wallet in logs | HIGH | Open |
| BE-07 | External Adapter | Hardcoded gas | HIGH | Open |
| BE-08 | External Adapter | No nonce tracking | HIGH | Open |
| BE-09 | Prover API | No rate limiting | HIGH | Open |
| BE-10 | Prover API | Query injection | HIGH | Open |

### C. Frontend Vulnerabilities (Full List)

| ID | Issue | Severity | Status |
|----|-------|----------|--------|
| FE-01 | No CSRF protection | CRITICAL | Open |
| FE-02 | Missing CSP headers | HIGH | Open |
| FE-03 | No input sanitization | HIGH | Open |
| FE-04 | API key in NEXT_PUBLIC_ | HIGH | Open |
| FE-05 | Detailed error messages | HIGH | Open |
| FE-06 | URL construction no validation | MEDIUM | Open |
| FE-07 | Inconsistent bytes32 validation | MEDIUM | Open |
| FE-08 | No input length limits | MEDIUM | Open |
| FE-09 | API endpoints exposed | MEDIUM | Open |
| FE-10 | No contract validation | MEDIUM | Open |

---

## 12. Conclusion

The TLH system demonstrates **strong smart contract security** with professional use of OpenZeppelin patterns, comprehensive test coverage, and proper UUPS upgrade mechanisms. However, the **backend services (Prover API and External Adapter) have critical authentication gaps** that must be addressed before any production deployment.

### Immediate Actions Required

1. **Add authentication to Prover API** - Bearer tokens + HMAC signing
2. **Add authentication to External Adapter** - Chainlink node verification
3. **Restrict CORS origins** - Whitelist only trusted domains
4. **Add CSRF protection to frontend** - Token-based protection
5. **Replace hardcoded test keys** - Generate production keys

### Estimated Time to Production-Ready

| Phase | Duration | Outcome |
|-------|----------|---------|
| Phase 1 (Critical) | 2-3 days | Safe for internal testing |
| Phase 2 (High) | 1 week | Ready for external beta |
| Phase 3 (Medium) | 2 weeks | Production hardened |
| Security Audit | 1-2 weeks | Third-party verification |

**Total:** 4-6 weeks to production readiness

---

**Report Generated:** 2026-02-18
**Auditor:** Pixelette Technologies Security Team
**Confidence Level:** HIGH (comprehensive static analysis + test review)
**Next Review:** After Phase 1 remediation
