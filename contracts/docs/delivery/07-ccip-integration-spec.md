# TLH CCIP Integration Specification

- Document Owner: TLH Chainlink Integration Lead (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Chainlink | Initial CCIP specification baseline |
| v1.0 | 2026-02-16 | TLH Chainlink | Added payload schema, validations, and acceptance tests |

## Use Cases and Message Flow
Primary use cases:
1. Trust A to Trust B credential transfer when clinician changes trust.
2. Cross-chain update propagation for attested credential state.
3. Provenance validation against shared anchor references.

High-level flow:
1. Source trust chain prepares credential transfer payload.
2. CCIP send transmits payload to destination trust chain handler.
3. Destination chain validates source and payload integrity.
4. Destination verifier/registry applies state update or rejects.
5. Status event emitted for audit trail.

## Payload Schema (Versioned)
Version: `CCIP_TLH_V1`

Required fields:
1. `version` (string) -> schema version identifier.
2. `sourceChainId` (uint256) -> originating trust chain.
3. `sourceTrustId` (bytes32) -> source trust identifier.
4. `subjectDID` (bytes32) -> credential subject DID hash.
5. `predicateType` (bytes32) -> credential/predicate type.
6. `valid` (bool) -> attested validity.
7. `expiresAt` (uint256) -> expiry timestamp.
8. `attestationId` (bytes32) -> source attestation reference.
9. `sharedAnchorRef` (bytes32) -> optional shared anchor hash reference.
10. `nonce` (uint256) -> anti-replay sequence.

Encoding recommendation:
1. ABI-encoded tuple with strict field ordering.
2. Optional additional hash commitment for tamper detection.

## Source/Destination Validation Rules
Source-side rules:
1. Only authorized sender role can initiate CCIP messages.
2. Payload must include current nonce and increment policy.

Destination-side rules:
1. `sourceChainId` must be in allowlist.
2. Sender contract address must be allowlisted.
3. Nonce must be fresh and monotonic.
4. Required fields must decode and pass structural checks.
5. If `sharedAnchorRef` provided, anchor consistency checks must pass.

## Failure Handling and Retries
Failure policy:
1. Decode/validation failures -> reject and emit failure event.
2. Temporary network failures -> retry with bounded attempts.
3. Duplicate/replayed nonce -> reject as replay.
4. Downstream write failure -> revert operation and emit failure metadata.

Retry controls:
1. Max retry attempts configurable.
2. Backoff strategy documented in operations runbook.
3. Failed-message queue review procedure required.

## Fee Model and Limits
Fee considerations:
1. CCIP fees depend on source/destination network and payload size.
2. Operational budget must include peak transfer scenarios.
3. Per-message payload size should remain bounded by schema requirements.

Recommended limits:
1. Cap payload size to deterministic fixed fields where possible.
2. Rate-limit sends from each source trust.
3. Maintain circuit-breaker for abnormal fee spikes.

## Test Scenarios and Acceptance Criteria
Minimum scenarios:
1. Happy-path send/receive with valid allowlisted source.
2. Reject non-allowlisted source chain.
3. Reject replayed nonce.
4. Reject malformed payload.
5. Downstream registry write failure path.
6. Retry and eventual success path.

Acceptance criteria:
1. All minimum scenarios pass in integration test environment.
2. Message audit trail events are emitted on success and failure.
3. Security checks (allowlist + nonce + source validation) are enforced.
4. Runbook and operational controls are documented and reviewed.

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________

