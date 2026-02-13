# ADR-003 — Hash Anchoring Strategy

## Status
Accepted

## Context

Trust Layer Health (TLH) requires a Shared Anchor Chain that provides privacy-preserving provenance for verified clinician credentials across trusts, without publishing underlying personal data.

The Shared Anchor Chain must:

- Allow relying parties to confirm the existence and freshness of a verified credential
- Enable cross-trust verification without disclosing credential contents
- Emit deterministic, indexable events for confirmation, refresh, revocation, and expiry
- Minimize on-chain storage while maintaining auditability
- Preserve verifiable linkage to the attestation that produced the credential state

The system architecture separates:

- **Shared Anchor Chain** → Public provenance + hash registry
- **Trust Private Chains** → Operational credential storage

We must define a consistent and governance-aligned anchoring model that specifies:

- What is anchored
- How anchors are keyed and indexed
- Whether anchors are append-only or overwrite
- How revocation and refresh are represented
- How anchoring links to the Attestation Verifier
- How gas/storage tradeoffs are handled

This ADR defines the authoritative anchoring strategy for M1 and establishes forward-compatible constraints for M3 and M5.

---

## Decision

### A) What Is Anchored

Only cryptographic hashes are stored on-chain.

Anchored values:

- `contentHash` (`bytes32`)
  - `keccak256(canonicalCredentialBytes)`
  OR
  - `keccak256(proofReferenceBytes)`

No raw credential JSON, PII, or VC payload data is stored on the Shared Anchor Chain.

Optional (future extension, not required for M1):
- Merkle root of batched credentials (`bytes32 vcRoot`)

Privacy is preserved by ensuring all stored values are one-way hashes.

---

### B) Keying / Addressing Model

Anchors are keyed by:

- `subjectDID` (`bytes32`)
- `vcType` (`bytes32`)

Where:

- `subjectDID` = deterministic hash representation of the clinician DID
- `vcType` = stable identifier (e.g. `keccak256("GMC_LICENSE")`)

Primary lookup key:

`(subjectDID, vcType)`

This allows:

- Efficient querying of a clinician's credential status
- Deterministic event filtering
- Cross-trust consistency

---

### C) Data Model — History Preserving (Append-Only)

The Shared Anchor Chain must preserve historical provenance while exposing a deterministic "current" state pointer.

Data structures:

```solidity
enum AnchorStatus { Active, Revoked }

struct AnchorRecord {
    bytes32 contentHash;
    uint256 anchoredAt;
    bytes32 attestationId;
    AnchorStatus status;
}

mapping(bytes32 => mapping(bytes32 => AnchorRecord[])) private _history;
mapping(bytes32 => mapping(bytes32 => uint256)) private _currentIndex;
```

Each `(subjectDID, vcType)` pair maintains:

- An append-only history array
- A pointer to the current active record

Semantics:
- New anchors are appended to `_history[did][vcType]`
- `_currentIndex[did][vcType]` points to the latest Active record
- Revocation updates the status of the current record (does NOT delete)

Rationale:
- Auditable provenance trail
- Supports refresh workflows without overwriting evidence
- Enables deterministic reconstruction of credential lifecycle

### D) Authorization Model
Only an authorized writer can create anchors:
- `ANCHOR_WRITER_ROLE` granted to the Shared Attestation Verifier contract
- Admin may grant/revoke writer role under governance controls (multisig)

Direct public anchoring is NOT allowed.

### E) Relationship: Attestation Verifier → Anchors
Anchoring is a side effect of a successful attestation verification:
1. Shared Attestation Verifier validates `(attestationId, predicateData, signature)`
2. Verifier derives:
   - `vcType` and `contentHash` from `predicateData`
3. Verifier calls `VCHashAnchors.anchorHash(subjectDID, vcType, contentHash, attestationId)`

This ensures:
- Every anchor has a verified attestation provenance link (`attestationId`)
- Writers cannot bypass verifier checks

### F) Revocation and Status Semantics
Revocation is represented on Shared Anchor Chain by marking the current anchor record as revoked.

Rules:
- Revocation is irreversible (cannot un-revoke). A new attestation must create a new active anchor.
- Revocation can be triggered by:
  - Shared Attestation Verifier (e.g., negative refresh result)
  - Admin emergency role (governed; multisig)

### G) Events (Success-Path Only)
Success-path events only (failure paths revert with custom errors):

- `HashAnchored(bytes32 indexed subjectDID, bytes32 indexed vcType, bytes32 contentHash, bytes32 indexed attestationId, uint256 anchoredAt)`
- `AnchorRevoked(bytes32 indexed subjectDID, bytes32 indexed vcType, bytes32 indexed attestationId, uint256 revokedAt)`

Indexing ensures efficient filtering by DID and VC type.

### H) Duplicate / Refresh Handling
If a new anchor is submitted with the same `(subjectDID, vcType)`:
- It is treated as a **refresh**:
  - Append a new `AnchorRecord`
  - Update `_currentIndex` to the new record
  - Emit `HashAnchored` for the new record
- If the new `contentHash` matches the current active hash, it is still appended ONLY if the attestationId differs (preserve provenance). Otherwise revert to avoid redundant writes.

## Alternatives Considered
### 1) Overwrite-only (single mapping)
Rejected: loses provenance history and hinders auditability.

### 2) Merkle root batching
Deferred: could reduce gas by batching many anchors into a merkle root committed periodically, but increases complexity for proof verification and is not required for M1.

### 3) Store full VC on-chain
Rejected: violates privacy, high gas cost, not acceptable for clinician data.

## Consequences
- Append-only history improves auditability and dispute resolution
- Only-hash storage preserves privacy and reduces chain bloat
- Strong authorization boundaries reduce attack surface
- Refresh and revocation workflows become explicit and queryable

## Implementation Notes (M1)
- `VCHashAnchors` contract implements UUPS + AccessControlUpgradeable
- `anchorHash(...)` restricted to `ANCHOR_WRITER_ROLE`
- `getAnchor(...)` returns current active record
- `getAnchorHistory(...)` returns full history for a DID+type
- Custom errors used for failure paths:
  - `error UnauthorizedAnchorWriter(address caller)`
  - `error AnchorNotFound(bytes32 subjectDID, bytes32 vcType)`
  - `error AnchorAlreadyRevoked(bytes32 subjectDID, bytes32 vcType)`
  - `error RedundantAnchor(bytes32 subjectDID, bytes32 vcType, bytes32 contentHash)`
