# TLH Contract Event Schema

All contracts follow a **success-path events only** policy.
Invalid operations revert with custom errors; no failure/rejection events are emitted.

---

## Shared Anchor Chain

### BaseAttestationVerifier

| Event | Parameters | Emitted when |
|-------|-----------|-------------|
| `AttestationSubmitted` | `attestationId` (indexed), `subjectDID` (indexed), `result`, `timestamp` | Attestation signature verified and stored |
| `SignerAdded` | `signer` (indexed) | Signer added to whitelist |
| `SignerRemoved` | `signer` (indexed) | Signer removed from whitelist |

### AttestationVerifier (Shared)

| Event | Parameters | Emitted when |
|-------|-----------|-------------|
| `DIDRegisteredViaAttestation` | `subjectDID` (indexed), `attestationId` (indexed) | DID registered as part of attestation flow (skipped if already exists) |
| `VCHashAnchoredViaAttestation` | `subjectDID` (indexed), `vcType` (indexed), `contentHash`, `attestationId` (indexed) | VC content hash anchored after verification |
| `CredentialStatusUpdated` | `subjectDID` (indexed), `vcType` (indexed), `result`, `attestationId` (indexed), `timestamp` | Full shared-anchor flow completed; composite status signal for subscribers |

### DIDRegistry

| Event | Parameters | Emitted when |
|-------|-----------|-------------|
| `DIDRegistered` | `did` (indexed), `controller` (indexed), `timestamp` | New DID registered |
| `DIDDeactivated` | `did` (indexed), `timestamp` | DID deactivated by controller |
| `DIDControllerUpdated` | `did` (indexed), `oldController` (indexed), `newController` (indexed) | DID controller changed |

### VCHashAnchors

| Event | Parameters | Emitted when |
|-------|-----------|-------------|
| `HashAnchored` | `subjectDID` (indexed), `vcType` (indexed), `contentHash`, `timestamp` | New VC content hash anchored |
| `AnchorRevoked` | `subjectDID` (indexed), `vcType` (indexed), `timestamp` | VC hash anchor revoked (irreversible) |

---

## Trust Private Chain

### TrustAttestationVerifier

| Event | Parameters | Emitted when |
|-------|-----------|-------------|
| `CredentialWrittenViaAttestation` | `subjectDID` (indexed), `predicateType` (indexed), `attestationId` (indexed) | Credential written to registry after **positive** attestation (result == true only; negative attestations are stored but do not write to registry) |

### CredentialRegistry

| Event | Parameters | Emitted when |
|-------|-----------|-------------|
| `CredentialWritten` | `subjectDID` (indexed), `predicateType` (indexed), `valid`, `attestationId`, `timestamp` | Credential record written or updated |
| `CredentialRevoked` | `subjectDID` (indexed), `predicateType` (indexed), `timestamp` | Credential revoked (irreversible status) |

---

## Custom Errors (failure paths)

All invalid operations revert with typed custom errors. No failure-path events are emitted.

### BaseAttestationVerifier
- `InvalidSignature()` -- ECDSA recovery failed
- `UnauthorizedSigner(address recovered)` -- signer not whitelisted
- `DuplicateAttestation(bytes32 attestationId)` -- replay attempt
- `EmptyPredicateData()` -- zero-length predicateData
- `ResultMismatch()` -- predicateData[0] != ABI-decoded result
- `ExpiredAttestation(uint256 expiresAt, uint256 nowTs)` -- positive attestation past expiry

### DIDRegistry
- `DIDAlreadyRegistered(bytes32 did)` -- DID already exists
- `DIDNotFound(bytes32 did)` -- DID not registered
- `NotDIDController(bytes32 did, address caller)` -- caller is not controller
- `DIDAlreadyDeactivated(bytes32 did)` -- DID already deactivated

### VCHashAnchors
- `UnauthorizedAnchorWriter(address caller)` -- caller lacks ANCHOR_WRITER_ROLE
- `AnchorNotFound(bytes32 subjectDID, bytes32 vcType)` -- no anchor exists
- `AnchorAlreadyRevoked(bytes32 subjectDID, bytes32 vcType)` -- anchor already revoked (durable)
- `ZeroAdminAddress()` -- admin == address(0) in initializer

### CredentialRegistry
- `UnauthorizedCredentialWriter(address caller)` -- caller lacks VERIFIER_ROLE
- `CredentialNotFound(bytes32 subjectDID, bytes32 predicateType)` -- no credential record
- `CredentialAlreadyRevoked(bytes32 subjectDID, bytes32 predicateType)` -- credential already revoked

---

## Subscriber Guidance

**For credential lifecycle tracking on the shared chain**, subscribe to:
1. `CredentialStatusUpdated` on `AttestationVerifier` -- single event for each verified attestation with result
2. `AnchorRevoked` on `VCHashAnchors` -- VC hash revocation (admin action)
3. `DIDDeactivated` on `DIDRegistry` -- DID deactivation (controller action)

**For trust-chain credential tracking**, subscribe to:
1. `CredentialWritten` on `CredentialRegistry` -- credential write/update with validity
2. `CredentialRevoked` on `CredentialRegistry` -- credential revocation
