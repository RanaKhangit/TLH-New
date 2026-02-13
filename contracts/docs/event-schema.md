# TLH — Shared Anchor Event Schema (M1)

Success-path events only. All invalid operations must revert with custom errors (no rejection events).

## Shared Attestation Verifier

### CredentialConfirmed
Emitted when a credential hash anchor is successfully written.
- subjectDID (indexed)
- vcType (indexed)
- attestationId
- timestamp

### CredentialRevoked
Emitted when an anchor is revoked via admin/emergency path.
- subjectDID (indexed)
- vcType (indexed)
- attestationId
- timestamp
- reason (string)

### CredentialExpired
Emitted when an anchor is marked expired via admin marker (subscriber signal).
- subjectDID (indexed)
- vcType (indexed)
- timestamp

### CredentialRefreshed
Emitted when a new attestation refreshes/updates a credential anchor.
- subjectDID (indexed)
- vcType (indexed)
- newAttestationId
- timestamp

## VC Hash Anchors
- HashAnchored (already emitted on anchor write)
- AnchorRevoked (already emitted on revocation)
