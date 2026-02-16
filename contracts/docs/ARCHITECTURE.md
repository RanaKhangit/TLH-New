# Trust Layer Health (TLH) — Architecture Document

## What This Document Covers

Everything we built during the Sepolia deployment and fork-testing phase:
- Deploy script, proxy wiring, and manifest generation
- Fork behaviour tests for both verifiers
- Tooling (manifest builder, contract lister, VC hasher)
- Foundry configuration changes

All decisions are explained in simple terms with reasoning.

---

## 1. System Overview

TLH verifies clinician credentials (e.g. "Is this doctor registered with the GMC?")
using Chainlink DECO attestations, then stores proof on-chain — without revealing
the underlying personal data.

There are **two chains** (both deployed to Sepolia for now):

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
               │                       │  │                       │
               │  AttestationVerifier   │  │ TrustAttestation-     │
               │        │              │  │      Verifier          │
               │        ▼              │  │        │               │
               │   ┌─────────┐         │  │        ▼               │
               │   │DID      │         │  │  ┌───────────────┐    │
               │   │Registry │         │  │  │Credential     │    │
               │   └─────────┘         │  │  │Registry       │    │
               │   ┌─────────┐         │  │  └───────────────┘    │
               │   │VCHash   │         │  │                       │
               │   │Anchors  │         │  │  Stores operational   │
               │   └─────────┘         │  │  credential state     │
               │                       │  │  (valid/expired/      │
               │  Stores hashes only   │  │   revoked)            │
               │  (privacy-preserving) │  │                       │
               └───────────────────────┘  └───────────────────────┘
```

**Why two chains?**
- The **Shared Anchor Chain** is public provenance — anyone can verify a credential
  exists without seeing the data. Only hashes are stored.
- The **Trust Private Chain** holds operational state — "is this credential still
  valid right now?" — used by the trust's own systems.

---

## 2. Contract Architecture

### 2.1 Inheritance Hierarchy

```
                    ┌──────────────────────────────┐
                    │  OpenZeppelin Upgradeable     │
                    │  ┌────────────────────────┐   │
                    │  │ Initializable           │   │
                    │  │ AccessControlUpgradeable│   │
                    │  │ UUPSUpgradeable         │   │
                    │  └────────────────────────┘   │
                    └──────────────┬────────────────┘
                                   │
                    ┌──────────────▼────────────────┐
                    │  BaseAttestationVerifier       │
                    │  (abstract)                    │
                    │                                │
                    │  • Signature verification      │
                    │  • Replay protection            │
                    │  • Signer whitelist             │
                    │  • _verifyAndStore()            │
                    │  • _onAttestationVerified()     │
                    │    (virtual — child decides     │
                    │     what happens on success)    │
                    └───────┬───────────────┬────────┘
                            │               │
              ┌─────────────▼───┐   ┌───────▼──────────────┐
              │ Attestation-    │   │ TrustAttestation-     │
              │ Verifier        │   │ Verifier              │
              │ (shared chain)  │   │ (trust chain)         │
              │                 │   │                       │
              │ On success:     │   │ On success:           │
              │ • Register DID  │   │ • Write credential    │
              │ • Anchor hash   │   │   to CredentialReg    │
              │ • Emit status   │   │                       │
              └─────────────────┘   └───────────────────────┘
```

**Why a shared base?**
Both verifiers do the same thing for steps 1-4 (check signature, prevent replay,
decode predicate, store attestation). They only differ in what happens *after*
verification succeeds. The base contract handles the shared logic; each child
implements `_onAttestationVerified()` with its chain-specific side effects.

### 2.2 The Five Deployable Contracts

```
┌──────────────────────┬────────────────────────────────────────────┐
│ Contract             │ Purpose                                    │
├──────────────────────┼────────────────────────────────────────────┤
│ DIDRegistry          │ Stores clinician DIDs (did:tlh:xyz)        │
│                      │ Controller-based ownership                 │
├──────────────────────┼────────────────────────────────────────────┤
│ VCHashAnchors        │ Stores credential content hashes           │
│                      │ Keyed by (subjectDID, vcType)              │
│                      │ Append-only history                        │
├──────────────────────┼────────────────────────────────────────────┤
│ AttestationVerifier  │ Shared chain verifier                      │
│                      │ Calls DIDRegistry + VCHashAnchors          │
├──────────────────────┼────────────────────────────────────────────┤
│ CredentialRegistry   │ Trust-local credential state               │
│                      │ Active / Expired / Revoked statuses        │
├──────────────────────┼────────────────────────────────────────────┤
│ TrustAttestation-    │ Trust chain verifier                       │
│ Verifier             │ Calls CredentialRegistry                   │
└──────────────────────┴────────────────────────────────────────────┘
```

---

## 3. UUPS Proxy Pattern (ADR-001)

Every contract is deployed as two pieces:

```
  User/Relayer
       │
       │  calls submitAttestation(...)
       ▼
  ┌──────────────────┐         ┌──────────────────────┐
  │  ERC1967 Proxy   │ ──────► │  Implementation      │
  │  (stores state)  │ delegatecall │  (stores logic) │
  │  (has address)   │         │  (no state)          │
  └──────────────────┘         └──────────────────────┘
```

**Why proxies?**
- We can upgrade the logic (fix bugs, add features) without changing the address
  or losing stored data.
- Users/integrators always interact with the same proxy address.
- The implementation contract has `_disableInitializers()` in its constructor
  so nobody can accidentally initialize it directly.

**Why UUPS specifically (not Transparent Proxy)?**
- UUPS puts the upgrade authorization *inside* the implementation contract
  (`_authorizeUpgrade` restricted to `UPGRADER_ROLE`).
- Simpler, cheaper, less surface area than Transparent Proxy's separate admin.
- Well-audited by OpenZeppelin and supported by Foundry.

---

## 4. Deployment Script Design

### File: `script/DeploySepolia.s.sol`

```
Deploy Order (matters because of dependency wiring):

  Step 1: Deploy 5 implementation contracts
  ┌─────────────────────────────────────────────┐
  │  DIDRegistry impl                           │
  │  VCHashAnchors impl                         │
  │  CredentialRegistry impl                    │
  │  TrustAttestationVerifier impl              │
  │  AttestationVerifier impl                   │
  └─────────────────────────────────────────────┘

  Step 2: Deploy proxies with initialize() calldata
  ┌─────────────────────────────────────────────┐
  │  DIDRegistry proxy ──► initialize(admin)    │
  │  VCHashAnchors proxy ──► initialize(admin)  │
  │  CredentialRegistry proxy ──► initialize(admin)│
  └─────────────────────────────────────────────┘
       │ These three have no dependencies,       │
       │ so they can be deployed in any order.   │

  Step 3: Deploy dependent proxies
  ┌─────────────────────────────────────────────┐
  │  TrustAttestVerifier proxy                  │
  │    ──► initialize(admin, credRegistryProxy) │
  │                                             │
  │  AttestationVerifier proxy                  │
  │    ──► initialize(admin, didProxy, vcProxy) │
  └─────────────────────────────────────────────┘
       │ These MUST come after step 2 because    │
       │ they need the proxy addresses as args.  │
```

**Why this order?**
- AttestationVerifier needs to know the DIDRegistry and VCHashAnchors proxy
  addresses at initialization time (they're stored as state variables).
- TrustAttestationVerifier needs the CredentialRegistry proxy address.
- If we deployed them in the wrong order, `initialize()` would receive
  `address(0)` or a non-existent contract.

**Key decision: `vm.envString` + `vm.parseUint` for private key**

We tried three approaches:
1. `vm.envUint("DEPLOYER_PRIVATE_KEY_UINT")` — original, but requires non-standard
   env var name and doesn't handle `0x` prefix
2. `vm.envBytes32(...)` — failed because Foundry's parser is strict about
   string length for bytes32
3. `vm.envString` + `vm.parseUint` — **chosen** because it accepts both
   `0x`-prefixed and plain hex private keys without any parsing issues

---

## 5. Cross-Contract Permission Model

```
                 ┌─────────────────────────────────┐
                 │         ADMIN (deployer)         │
                 │  0x3B50966A...                   │
                 │                                  │
                 │  Has DEFAULT_ADMIN_ROLE on all   │
                 │  contracts. Can grant any role.  │
                 └──────┬──────────────┬────────────┘
                        │              │
          ┌─────────────▼───┐   ┌──────▼──────────────┐
          │ DIDRegistry     │   │ VCHashAnchors       │
          │                 │   │                     │
          │ REGISTRAR_ROLE  │   │ ANCHOR_WRITER_ROLE  │
          │ needed to call  │   │ needed to call      │
          │ registerDID()   │   │ anchorHash()        │
          └────────▲────────┘   └────────▲────────────┘
                   │                     │
                   │  calls              │  calls
                   │                     │
          ┌────────┴─────────────────────┴────────────┐
          │       AttestationVerifier proxy            │
          │       (must be granted both roles)         │
          └───────────────────────────────────────────┘

          ┌──────────────────────────────────────────┐
          │       CredentialRegistry                  │
          │                                          │
          │       VERIFIER_ROLE needed to call       │
          │       writeCredential()                  │
          └────────────────▲─────────────────────────┘
                           │  calls
                           │
          ┌────────────────┴─────────────────────────┐
          │    TrustAttestationVerifier proxy         │
          │    (must be granted VERIFIER_ROLE)        │
          └──────────────────────────────────────────┘
```

**Why role-based access?**
- Only the verifier contracts should be able to write to the registries.
- If someone got hold of a signer key, they could submit attestations to the
  verifier — but they still can't directly write to DIDRegistry or
  CredentialRegistry. The verifier is the gatekeeper.
- Roles are granted on Sepolia via `cast send ... grantRole(...)`.

**Role hashes (computed via `cast keccak`):**
- `VERIFIER_ROLE` = `0x0ce23c3e399818cfee81a7ab0880f714e53d7672b08df0fa62f2843416e1ea09`
- `REGISTRAR_ROLE` = `keccak256("REGISTRAR_ROLE")`
- `ANCHOR_WRITER_ROLE` = `keccak256("ANCHOR_WRITER_ROLE")`

---

## 6. Attestation Flow (End-to-End)

### 6.1 Shared Chain Flow

```
  Relayer (off-chain)
       │
       │  submitAttestation(attestationId, subjectDID, predicateData, signature)
       ▼
  ┌──────────────────────────────────┐
  │  AttestationVerifier proxy       │
  │                                  │
  │  1. Check: not duplicate?        │──── revert DuplicateAttestation
  │  2. Check: predicateData empty?  │──── revert EmptyPredicateData
  │  3. Decode result byte + ABI     │
  │  4. Check: result byte == ABI?   │──── revert ResultMismatch
  │  5. Check: not expired?          │──── revert ExpiredAttestation
  │  6. Compute chain-bound digest   │
  │  7. ECDSA recover signer         │──── revert InvalidSignature
  │  8. Check: signer whitelisted?   │──── revert UnauthorizedSigner
  │  9. Store attestation record     │
  │ 10. emit AttestationSubmitted    │
  │                                  │
  │  If result == false: STOP        │
  │  If result == true:              │
  │    │                             │
  │    ▼                             │
  │  _onAttestationVerified()        │
  │    │                             │
  │    ├─► DIDRegistry.registerDID() │
  │    │   (swallow if already       │
  │    │    registered)              │
  │    │                             │
  │    ├─► VCHashAnchors.anchorHash()│
  │    │                             │
  │    └─► emit CredentialStatus-    │
  │        Updated                   │
  └──────────────────────────────────┘
```

### 6.2 Trust Chain Flow

```
  Relayer (off-chain)
       │
       │  submitAttestation(...)
       ▼
  ┌──────────────────────────────────┐
  │  TrustAttestationVerifier proxy  │
  │                                  │
  │  Steps 1-10: identical to above  │
  │                                  │
  │  If result == true:              │
  │    │                             │
  │    ▼                             │
  │  _onAttestationVerified()        │
  │    │                             │
  │    └─► CredentialRegistry        │
  │        .writeCredential(         │
  │          subjectDID,             │
  │          predicateType,          │
  │          result,                 │
  │          expiresAt,              │
  │          attestationId           │
  │        )                         │
  │                                  │
  │    └─► emit CredentialWritten-   │
  │        ViaAttestation            │
  └──────────────────────────────────┘
```

**Why does `result == false` skip side-effects?**
- A negative attestation means "this credential check failed."
- We still *store* it (for audit trail), but we don't register the DID or
  anchor a hash — there's nothing valid to anchor.
- This is the key insight behind the storage-only vs side-effects test split.

---

## 7. Signature Scheme (ADR-002)

```
  Digest Construction:
  ┌─────────────────────────────────────────────┐
  │  inner = keccak256(                         │
  │    "TLH_ATTESTATION_V1"    // domain tag    │
  │    ++ block.chainid        // chain binding │
  │    ++ address(this)        // contract addr │
  │    ++ attestationId        // unique ID     │
  │    ++ subjectDID           // who           │
  │    ++ keccak256(predicateData) // what      │
  │  )                                          │
  │                                             │
  │  digest = EIP-191 prefix(inner)             │
  │         = keccak256("\x19Ethereum Signed    │
  │           Message:\n32" ++ inner)           │
  └─────────────────────────────────────────────┘

  Then: recovered = ECDSA.recover(digest, signature)
  Then: require(signerWhitelist[recovered] == true)
```

**Why chain-bound?**
- Without `block.chainid`, the same signature could be replayed on a different
  network (e.g. mainnet vs Sepolia).
- Without `address(this)`, the same signature could be replayed on the Trust
  verifier vs the Shared verifier.
- This prevents all cross-chain and cross-contract replay attacks.

---

## 8. Fork Behaviour Tests

### Why Fork Tests (Not Just Unit Tests)?

Unit tests (in `test/shared/`, `test/trust/`) test contracts in isolation
using local deployments. Fork tests hit the **real Sepolia state**:

```
  ┌─────────────────────────────────────────────┐
  │  Forge Test Runner                          │
  │                                             │
  │  vm.createSelectFork(SEPOLIA_RPC, BLOCK)    │
  │       │                                     │
  │       ▼  fetches real on-chain state        │
  │  ┌─────────────────────────────────┐        │
  │  │  Local Fork of Sepolia          │        │
  │  │                                 │        │
  │  │  Real proxy contracts           │        │
  │  │  Real storage slots             │        │
  │  │  Real role assignments          │        │
  │  │  Real dependency wiring         │        │
  │  │                                 │        │
  │  │  But: state changes are LOCAL   │        │
  │  │  (nothing hits real Sepolia)    │        │
  │  └─────────────────────────────────┘        │
  └─────────────────────────────────────────────┘
```

**Why pin `FORK_BLOCK`?**
- Makes tests deterministic. Without it, `block.timestamp` changes between
  runs, which changes attestation IDs and digest computations.
- If someone grants a role at block N, we set `FORK_BLOCK=N` so the test
  always sees the grant.

### Test Structure: Storage-Only vs Side-Effects

```
  ┌──────────────────────────────────┐
  │  test_HappyPath_StorageOnly      │
  │                                  │
  │  result = false                  │
  │  ──► attestation stored ✓       │
  │  ──► no DID registered          │
  │  ──► no hash anchored           │
  │  ──► no credential written      │
  │                                  │
  │  Tests: BaseAttestationVerifier  │
  │  logic in isolation              │
  └──────────────────────────────────┘

  ┌──────────────────────────────────┐
  │  test_HappyPath_SideEffects      │
  │                                  │
  │  result = true                   │
  │  ──► attestation stored ✓       │
  │  ──► DID registered ✓           │
  │  ──► hash anchored ✓            │
  │  ──► credential written ✓       │
  │                                  │
  │  Tests: full cross-contract flow │
  │  Requires role grants on Sepolia │
  └──────────────────────────────────┘
```

**Why split them?**
- The storage-only test passes immediately — it proves the core verification
  logic works without needing any role grants.
- The side-effects test will fail until roles are granted. This isolates
  "verification works" from "permissions are configured" — two separate concerns.

### Dynamic Dependency Resolution

```solidity
// We do NOT hardcode DIDRegistry or VCHashAnchors addresses.
// Instead we read them from the deployed proxy at runtime:

verifier = IAttestationVerifierWithDeps(PROXY_ADDRESS);
did = IDIDRegistryRead(verifier.didRegistry());    // reads storage slot
vca = IVCHashAnchorsRead(verifier.vcHashAnchors()); // reads storage slot
```

**Why?**
- If the admin ever upgrades or repoints a dependency, the tests automatically
  follow. No hardcoded addresses to update.

---

## 9. Tooling Decisions

### 9.1 Deployment Manifest (`deployment-manifest.sepolia.json`)

```json
{
  "contracts": {
    "DIDRegistry": {
      "implementation": "0xdeecd6a...",
      "proxy": "0x6c6fa7f...",
      "implDeployTx": "0xef57c1d...",
      "proxyDeployTx": "0x617557c..."
    }
  }
}
```

**Why separate impl/proxy tx hashes?**
- The original manifest only had one `deployTx` per contract, which was the
  implementation deploy. But for verification on Etherscan or audit evidence,
  you need both the implementation *and* proxy deploy transactions.

### 9.2 `list-created-contracts.js`

Reads Foundry's `run-latest.json` broadcast output and lists all created
contracts with their names, addresses, and tx hashes.

**Why?**
- Foundry's broadcast JSON is large and hard to read manually. The proxy
  contracts show up as `ERC1967Proxy` (not `DIDRegistry`), so you need a
  tool to match them up by deploy order.

### 9.3 `hash_vc.mjs`

Canonical JSON serialization + SHA-256 hash of a VC document.

**Why SHA-256 (not keccak256)?**
- VC specifications use SHA-256 as the standard hash algorithm.
- The hash is stored as `bytes32` on-chain in VCHashAnchors.
- Canonical JSON (sorted keys, no whitespace variance) ensures the same VC
  always produces the same hash, regardless of formatting.

### 9.4 Foundry Configuration Changes

Added `via_ir = true` to `foundry.toml`:

**Why?**
- The Yul intermediate representation pipeline produces more optimized
  bytecode, especially for contracts with complex inheritance chains
  (like our verifiers that inherit from 3+ OpenZeppelin bases).
- Prevents "stack too deep" errors that can occur with the legacy pipeline
  when contracts have many local variables.

---

## 10. Sepolia Deployment Map

```
  ┌─────────────────────────────────────────────────────────────┐
  │                    Sepolia (Chain 11155111)                  │
  │                                                             │
  │  Deployer/Admin: 0x3B50966A8B71f277e90e14cdC31455F6Af3977e6│
  │                                                             │
  │  ┌─────────────────┐  ┌─────────────────┐                  │
  │  │ DIDRegistry     │  │ VCHashAnchors   │                  │
  │  │ proxy:          │  │ proxy:          │                  │
  │  │ 0x6c6fa7f9...   │  │ 0x95d02ae2...   │                  │
  │  │ impl:           │  │ impl:           │                  │
  │  │ 0xdeecd6a9...   │  │ 0x3b7803ba...   │                  │
  │  └────────▲────────┘  └────────▲────────┘                  │
  │           │                    │                            │
  │           │    calls           │    calls                   │
  │           │                    │                            │
  │  ┌────────┴────────────────────┴────────┐                  │
  │  │ AttestationVerifier                  │                  │
  │  │ proxy: 0xce863e46...                 │                  │
  │  │ impl:  0x2ae518d8...                 │                  │
  │  └─────────────────────────────────────┘                  │
  │                                                             │
  │  ┌─────────────────┐                                       │
  │  │ CredentialReg   │                                       │
  │  │ proxy:          │                                       │
  │  │ 0xae4b7177...   │                                       │
  │  │ impl:           │                                       │
  │  │ 0x94de2311...   │                                       │
  │  └────────▲────────┘                                       │
  │           │    calls                                       │
  │           │                                                │
  │  ┌────────┴──────────────────────────────┐                 │
  │  │ TrustAttestationVerifier              │                 │
  │  │ proxy: 0x2ad7540b...                  │                 │
  │  │ impl:  0x893aad8b...                  │                 │
  │  └──────────────────────────────────────┘                  │
  │                                                             │
  │  Total gas: ~0.0447 ETH                                    │
  └─────────────────────────────────────────────────────────────┘
```

---

## 11. Decision Log (Summary)

| # | Decision | Reasoning |
|---|----------|-----------|
| 1 | UUPS over Transparent Proxy | Simpler, cheaper, upgrade logic in implementation not admin contract |
| 2 | Shared base contract | Both verifiers share 90% of logic; DRY principle avoids bugs |
| 3 | result=false skips side-effects | No point registering DIDs or anchoring hashes for failed checks |
| 4 | Chain-bound signatures | Prevents cross-chain and cross-contract signature replay |
| 5 | Success-path events only | Failed operations revert with custom errors — cleaner than rejection events |
| 6 | Hash-only storage on shared chain | Privacy-preserving; no PII on-chain |
| 7 | Append-only anchor history | Audit trail; can reconstruct credential lifecycle |
| 8 | Separate storage-only vs side-effects tests | Isolates "verification works" from "permissions are configured" |
| 9 | Dynamic dependency resolution in tests | Tests survive dependency upgrades without code changes |
| 10 | Pinned FORK_BLOCK | Deterministic fork tests; tracks role grant state |
| 11 | `vm.envString` + `vm.parseUint` for PK | Handles both 0x-prefixed and plain hex private keys |
| 12 | `via_ir = true` in foundry.toml | Better optimization, prevents stack-too-deep with deep inheritance |
| 13 | Split implDeployTx / proxyDeployTx in manifest | Audit evidence needs both transactions, not just one |
| 14 | Role-gated cross-contract writes | Defense in depth — even with a compromised signer, direct registry writes are blocked |
| 15 | Canonical JSON hashing for VCs | Deterministic hashes regardless of JSON formatting |

---

## 12. What Remains (Mechanical)

These are not architectural decisions — they are operational steps:

1. **Grant REGISTRAR_ROLE** on DIDRegistry to AttestationVerifier proxy
2. **Grant ANCHOR_WRITER_ROLE** on VCHashAnchors to AttestationVerifier proxy
3. **Grant VERIFIER_ROLE** on CredentialRegistry to TrustAttestationVerifier proxy
4. **Add signer** to both verifier whitelists via `addSigner(address)`
5. **Pin FORK_BLOCK** after grants and re-run fork tests
6. **CI/CD pipeline** — GitHub Actions for `forge build && forge test`
