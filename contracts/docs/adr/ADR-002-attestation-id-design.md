# ADR-002 — Attestation ID and Predicate Schema Design

## Status
Accepted

## Context
TLH requires a deterministic, replay-safe, privacy-preserving on-chain representation of verified credential predicates. The Chainlink DON (or a relayer on behalf of the DON) submits signed attestations to:
- Shared Anchor Chain verifier (writes provenance: DID registry + VC hash anchors + status events)
- Trust Private Chain verifier (writes operational credential state to a trust-local registry)

We must standardize:
- Attestation identifier (uniqueness, replay protection)
- Predicate result schema (what is stored and what is emitted)
- Signature verification model (whitelisted signers, ECDSA recovery)
- How the same schema supports Shared Anchor and Trust-Local verifiers

## Decision

### A) Attestation ID Generation
Attestation IDs MUST be unique and deterministic for a given attestation payload. The canonical scheme is:

`attestationId = keccak256(abi.encodePacked(subjectDID, predicateType, checkedAt, expiresAt, nonce, domainSeparator))`

Where:
- `subjectDID` (bytes32): DID of the subject (physician)
- `predicateType` (bytes32): a stable identifier for the predicate (e.g., `keccak256("GMC_REGISTERED")`)
- `checkedAt` (uint256): UNIX timestamp of verification
- `expiresAt` (uint256): UNIX timestamp when this predicate expires (0 if non-expiring)
- `nonce` (bytes32): relayer/DON-supplied nonce to prevent collisions for same inputs
- `domainSeparator` (bytes32): chain-agnostic domain separation constant for TLH, e.g. `keccak256("TLH_ATTESTATION_V1")`

Rationale:
- Uniqueness: nonce allows multiple attestations for same predicate/time windows
- Replay protection: contract stores `attestationUsed[attestationId] = true`
- Cross-chain consistency: same ID can be submitted to Shared + Trust verifiers

### B) On-Chain Predicate Result Schema
Contracts MUST store a minimal attestation record. The canonical struct:

```solidity
struct Attestation {
    bytes32 subjectDID;
    bytes32 predicateType;
    bool    result;
    uint256 checkedAt;
    uint256 expiresAt;
    address signer;      // recovered signer (whitelist-validated)
    bytes32 dataHash;    // keccak256(predicateData) for integrity; raw data not stored
}
```

Notes:
- `predicateData` is accepted as `bytes` at submission time but MUST NOT be stored raw on-chain.
- Only `dataHash` is stored to preserve privacy and reduce gas.

### C) Predicate Data Encoding (Off-chain to On-chain)
`predicateData` is a `bytes` blob with a **leading result byte** followed by an ABI-encoded payload:

```
predicateData[0]   = 0x01 (true) | 0x00 (false)   — result flag consumed by BaseAttestationVerifier
predicateData[1:]  = abi.encode(predicateType, result, checkedAt, expiresAt, vcType, contentHash, extra)
```

The base verifier reads `predicateData[0]` to determine the boolean `result`. Chain-specific hooks decode `predicateData[1:]` to extract fields.

Where:
- `predicateType` (bytes32)
- `result` (bool) — mirrors predicateData[0] for ABI-decode convenience
- `checkedAt` (uint256)
- `expiresAt` (uint256)
- `vcType` (bytes32): credential type identifier (e.g., `keccak256("GMC_LICENSE")`)
- `contentHash` (bytes32): privacy-preserving VC content hash (or proof reference hash)
- `extra` (bytes): optional extension field (empty in M1 unless explicitly required)

### D) DON Signature Verification
All verifier contracts MUST validate signatures using ECDSA recovery against a signer whitelist.

- Use OpenZeppelin `ECDSA` helpers (or equivalent) to recover `recoveredSigner`
- Require `signers[recoveredSigner] == true` else revert

Signature payload MUST be:

`messageHash = keccak256(abi.encodePacked(block.chainid, address(this), attestationId, subjectDID, keccak256(predicateData)))`

Then apply EIP-191 prefixing:

`ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash)`

Recover signer from `signature` over `ethSignedMessageHash`.

> **Note:** The signed payload binds `block.chainid` and `address(this)` to prevent cross-chain and cross-contract replay, and `subjectDID` to prevent cross-subject replay. `keccak256(predicateData)` covers the full blob including the leading result byte.

### E) Replay Protection
Verifiers MUST enforce one-time use of each `attestationId`:
- If `attestationUsed[attestationId] == true` then revert `DuplicateAttestation(attestationId)`
- On success: set `attestationUsed[attestationId] = true` and store attestation record

### F) Shared Anchor vs Trust-Local Compatibility
Both verifiers MUST accept the same:
- `attestationId`
- `predicateData` encoding
- signature scheme

Chain-specific effects occur after verification:
- Shared: register/confirm DID + write VC hash anchor + emit status events
- Trust: write credential state to Credential Registry

## Mapping to PoC Flow 1 (Steps 2-3)
- Step 2: Relayer submits `(attestationId, subjectDID, predicateData, signature)` to Shared Attestation Verifier
- Step 3: On success, Shared verifier triggers:
  - DIDRegistry register/confirm (if missing)
  - VCHashAnchors anchor write (contentHash)
  - success-path confirmation events

## Indexing Strategy (Events)
All success-path events MUST index:
- `subjectDID` as `indexed`
- `vcType` or `predicateType` as `indexed`
- `attestationId` as `indexed` where present

This enables efficient event filtering by DID and credential type/predicate.

## Custom Errors
Contracts MUST use custom errors for failure paths (no rejection events):
- `error InvalidSignature()`
- `error UnauthorizedSigner(address recovered)`
- `error DuplicateAttestation(bytes32 attestationId)`
- `error EmptyPredicateData()`
- `error ExpiredAttestation(uint256 expiresAt, uint256 nowTs)` (used when expiry is enforced during submit)

## Consequences
- Minimal on-chain storage (hashes only) improves privacy and reduces gas
- Deterministic IDs support cross-chain mirroring and auditing
- Strict replay protection prevents duplicate submissions
- Whitelist-based ECDSA model allows trust-specific signer policies (shared vs trust verifiers)
