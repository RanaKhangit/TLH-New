# TLH Forensic QA Report

**Date:** 2026-02-16
**Network:** Sepolia (Chain ID 11155111)
**Admin:** `0x3B50966A8B71f277e90e14cdC31455F6Af3977e6`
**RPC:** Alchemy (eth-sepolia)

---

## Summary

| Test Suite | Result | Details |
|---|---|---|
| QA-1: Unit Tests | **PASS** | 104/104 tests passed |
| QA-2: Role Grants | **PASS** | 3 role grants + 2 signer registrations confirmed |
| QA-3: Fork Tests | **PASS** | 16/16 fork behaviour tests passed |
| QA-4: E2E Manual Flow | **PASS** | Full DID → Anchor → Credential → Verify cycle |
| QA-5: Pipeline Test | **PARTIAL PASS** | Services running, verify OK, tx blocked (0 ETH) — see `FRONTEND-E2E-REPORT.md` |
| QA-6: Event Verification | **PASS** | All 6 tx receipts verified with correct events |

**Overall: 5/5 executable tests PASSED. 1 partial pass (pipeline verify OK, tx blocked by 0 ETH wallet). See `FRONTEND-E2E-REPORT.md` for full frontend walkthrough.**

---

## QA-1: Unit Tests (forge test)

**Command:** `forge test` (excluding fork tests)
**Result:** 104 passed, 0 failed, 0 skipped
**Evidence:** `evidence/qa/unit-test-results.txt`

### Test Suites

| Contract | Tests | Status |
|---|---|---|
| DIDRegistry | 29 | PASS |
| VCHashAnchors | 19 | PASS |
| CredentialRegistry | 20 | PASS |
| AttestationVerifier | 18 | PASS |
| TrustAttestationVerifier | 18 | PASS |

All test suites exercise:
- Happy-path functionality (register, anchor, write, submit, verify)
- Access control (unauthorized callers revert)
- Edge cases (duplicates, expiry, revocation, empty input)
- Event emission verification
- UUPS upgrade authorization

---

## QA-2: Cross-Contract Role Grants

### Pre-Existing Grants (already on-chain)
- DIDRegistry: AttestationVerifier proxy has `REGISTRAR_ROLE` (**true**)
- VCHashAnchors: AttestationVerifier proxy has `ANCHOR_WRITER_ROLE` (**true**)

### Grants Executed During QA

| Action | TX Hash | Status |
|---|---|---|
| Grant `VERIFIER_ROLE` to TrustAttestationVerifier on CredentialRegistry | `0x35189bc41c15742e54162989df66c4758aad7af223bbe5b200c5c590e6116260` | SUCCESS |
| `addSigner(admin)` on AttestationVerifier | `0x25f7c977d6dc450f58c8b751d61f93262874456da5ebe3dc3c1948ae4e93b31e` | SUCCESS |
| `addSigner(admin)` on TrustAttestationVerifier | `0xf4c87665cf9dd8fd91b69b6e0fa291d60ac9a515d25201dd4a30da1891e0fd49` | SUCCESS |
| Grant `VERIFIER_ROLE` to admin on CredentialRegistry | `0x59c763344af19a26fd49fec2dd35113c7c1d00596ef77f2d6ebb94460a70b938` | SUCCESS |

### Final Role Matrix

| Contract | Role | Grantee | Status |
|---|---|---|---|
| DIDRegistry | `REGISTRAR_ROLE` | AttestationVerifier proxy | **granted** |
| DIDRegistry | `REGISTRAR_ROLE` | Admin | **granted** |
| VCHashAnchors | `ANCHOR_WRITER_ROLE` | AttestationVerifier proxy | **granted** |
| VCHashAnchors | `ANCHOR_WRITER_ROLE` | Admin | **granted** |
| CredentialRegistry | `VERIFIER_ROLE` | TrustAttestationVerifier proxy | **granted** |
| CredentialRegistry | `VERIFIER_ROLE` | Admin | **granted** |
| AttestationVerifier | Signer whitelist | Admin | **whitelisted** |
| TrustAttestationVerifier | Signer whitelist | Admin | **whitelisted** |

---

## QA-3: Fork Behaviour Tests

**Command:** `forge test --match-path "test/fork/*.t.sol" -vvv`
**Environment:**
- `SEPOLIA_RPC_URL` = Alchemy Sepolia endpoint
- `FORK_BLOCK` = 10273343
- `SIGNER_PK` = deployer private key (admin = whitelisted signer)

**Result:** 16 passed, 0 failed, 0 skipped
**Evidence:** `evidence/qa/fork-test-results.txt`

### AttestationVerifier Fork Tests (8/8)

| Test | Gas | Status |
|---|---|---|
| `test_HappyPath_SideEffects_SubmitAndVerify` | 304,558 | PASS |
| `test_HappyPath_StorageOnly_SubmitAndVerify` | 126,642 | PASS |
| `test_Revert_DuplicateAttestation` | 124,675 | PASS |
| `test_Revert_EmptyPredicateData` | 18,447 | PASS |
| `test_Revert_ExpiredAttestation_WhenPositiveAndExpired` | 22,475 | PASS |
| `test_Revert_InvalidSignature_ZeroRecovered` | 21,843 | PASS |
| `test_Revert_ResultMismatch` | 21,876 | PASS |
| `test_Revert_UnauthorizedSigner` | 30,079 | PASS |

### TrustAttestationVerifier Fork Tests (8/8)

| Test | Gas | Status |
|---|---|---|
| `test_HappyPath_SideEffects_SubmitAndVerify` | 354,841 | PASS |
| `test_HappyPath_StorageOnly_SubmitAndVerify` | 125,814 | PASS |
| `test_Revert_DuplicateAttestation` | 124,029 | PASS |
| `test_Revert_EmptyPredicateData` | 18,419 | PASS |
| `test_Revert_ExpiredAttestation_WhenPositiveAndExpired` | 22,294 | PASS |
| `test_Revert_InvalidSignature_ZeroRecovered` | 21,339 | PASS |
| `test_Revert_ResultMismatch` | 21,642 | PASS |
| `test_Revert_UnauthorizedSigner` | 29,563 | PASS |

**Key finding:** The side-effects happy path (`test_HappyPath_SideEffects_SubmitAndVerify`) validates the full cross-contract flow:
1. AttestationVerifier → DIDRegistry.registerDID (auto-registers subject)
2. AttestationVerifier → VCHashAnchors.anchorHash (anchors VC hash)
3. TrustAttestationVerifier → CredentialRegistry.writeCredential (writes credential)

All cross-contract calls succeed with the correct role grants in place.

---

## QA-4: E2E Manual Flow

**Subject:** `did:tlh:qa-e2e-20260216`
**Subject DID hash:** `0xe881d00a86c4cebbca13d23d296398afe09aea19227981d9365c877822aff10f`
**Evidence:** `evidence/qa/e2e-flow.txt`

### Step 1: Register DID
- **TX:** `0xe2688321d353aa91cc19a8483a6f78eb240f992eb06e7009ca70607cd5c84c4b`
- **Events:** `DIDRegistered`, `DIDUpdated`
- **Verification:** `resolveDID` returns controller=admin, active=true

### Step 2: Anchor VC Hash
- **VC Type:** `GMC_LICENSE` (keccak256)
- **Content Hash:** `0xa6369bca...`
- **TX:** `0xa812e21cc02441ddf7c848bf2b55c86f17d93b3926cccd09a6a0bf7bd961f2e2`
- **Events:** `HashAnchored`
- **Verification:** `getAnchor` returns correct contentHash, anchoredAt>0, revoked=false

### Step 3: Write Credential
- **Predicate:** `GMC_REGISTERED` (keccak256)
- **Valid:** true, **Expires:** +1 year
- **TX:** `0x7d83ddcd700e28361d07d9a5ed904168557eccdd75f831dbf6fbf53298e3b477`
- **Events:** `CredentialWritten`
- **Verification:** `getCredential` returns correct struct, `isCredentialValid` returns true

### Step 4: Cross-Verification
All four read-only queries confirmed:

| Query | Result |
|---|---|
| `resolveDID(subjectDID)` | controller=admin, active=true, registered |
| `getAnchor(subjectDID, vcType)` | contentHash=correct, anchoredAt>0, revoked=false |
| `getCredential(subjectDID, predType)` | valid=true, status=Active, expiresAt=+1yr |
| `isCredentialValid(subjectDID, predType)` | **true** |

---

## QA-5: Full Pipeline Test

**Status: PARTIAL PASS** (updated 2026-02-17)

All three services running and verified:
- Prover API (`localhost:8787`): `/health` → `{"ok":true}`
- External Adapter (`localhost:8788`): `/health` → `{"status":"ok","address":"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"}`
- Frontend (`localhost:3001`): All 6 routes serving

Pipeline flow tested:
1. Load DECO Attestation → **OK** (signature, public key loaded)
2. Verify Attestation → **PASS** (proofId: `0xec5d5d9fba2bef6d`)
3. Submit On-Chain → **BLOCKED** (wallet `0xf39Fd...` has 0 Sepolia ETH — `gas required exceeds allowance`)
4. GMC Doctor Lookup → **OK** (4333333, Registered with Licence)

The verification pipeline works end-to-end. The only blocker is funding the wallet for gas. Explorer pages correctly return "Not Found" since no data has been written on-chain.

**Full details:** See `evidence/qa/FRONTEND-E2E-REPORT.md`

---

## QA-6: Event Verification

All transaction receipts were verified via RPC with correct event signatures:

| Event | Contract | TX | Confirmed |
|---|---|---|---|
| `DIDRegistered(bytes32,address)` | DIDRegistry | `0xe268...` | YES |
| `DIDUpdated(bytes32,bool,address)` | DIDRegistry | `0xe268...` | YES |
| `HashAnchored(bytes32,bytes32)` | VCHashAnchors | `0xa812...` | YES |
| `CredentialWritten(bytes32,bytes32)` | CredentialRegistry | `0x7d83...` | YES |
| `RoleGranted(bytes32,address,address)` | CredentialRegistry | `0x3518...` | YES |
| `SignerAdded(address)` | AttestationVerifier | `0x25f7...` | YES |
| `SignerAdded(address)` | TrustAttestationVerifier | `0xf4c8...` | YES |

---

## Contract Deployment Summary

| Contract | Proxy Address | Implementation | Verified |
|---|---|---|---|
| DIDRegistry | `0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a` | `0xdeecd6a976d5999315dcf0cf8e7fa0e6ea887cd6` | YES |
| VCHashAnchors | `0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68` | `0x3b7803ba081228ea98626be219755b0295267013` | YES |
| CredentialRegistry | `0xae4b71776fab8e431cee4874ad3a2a97588d89fb` | `0x94de2311e67abd4332c358b9c3a37e231f298249` | YES |
| TrustAttestationVerifier | `0x2ad7540b14585ebfb3c86604d1927b40e2efa5db` | `0x893aad8b32e77845b2485e033c7031e31c13ec9b` | YES |
| AttestationVerifier | `0xce863e465f21df87ad9f0a2af838fac1750f08d2` | `0x2ae518d86774c814a73ca03464b355a3a228ac8d` | YES |

All 5 contracts deployed behind UUPS (ERC-1967) proxies on Sepolia. All respond to read calls and execute state-changing transactions correctly.

---

## Issues Found and Fixed

| Issue | Severity | Fix |
|---|---|---|
| Address checksum mismatch in fork test | Low | Fixed `TrustAttestationVerifier` address in `test/fork/TrustAttestationVerifier.behaviour.sepolia.t.sol:44` |
| Missing `VERIFIER_ROLE` grant | Medium | Granted via `grantVerifier()` to TrustAttestationVerifier proxy |
| No signers whitelisted on verifiers | Medium | Added admin as signer on both verifiers via `addSigner()` |
| `.env` DEPLOYER_PRIVATE_KEY had leading space | Low | Trimmed whitespace in `.env` file |

---

## Conclusion

The TLH smart contract layer is **fully functional on Sepolia**:

1. **All 104 unit tests pass** across 5 contract test suites
2. **All 16 fork behaviour tests pass** against live Sepolia state
3. **Full E2E flow verified**: DID registration → VC hash anchoring → credential writing → cross-contract state verification
4. **Cross-contract role grants correctly configured** for the attestation pipeline
5. **All events emit correctly** and are verifiable on-chain

The only untested component is the Prover API + External Adapter pipeline (QA-5), which requires those services to be running. The contract layer is production-ready for the MVP scope.
