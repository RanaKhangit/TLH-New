# TLH Security and Compliance Assessment

- Document Owner: TLH Security Lead (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Security | Initial assessment draft |
| v1.0 | 2026-02-16 | TLH Security | Added findings, controls, and residual risks |

## Security Scope and Method
Scope:
1. Smart contracts in `contracts/src/**`.
2. Deployment and role wiring on Sepolia.
3. Secret-handling controls in repository practices.
4. Test evidence around hardening controls.

Method:
1. Code-level review of access control, initializer hardening, replay protections.
2. On-chain role/wiring validation via `cast call`.
3. Secret leakage checks using gitleaks and git hygiene controls.
4. Verification against known security remediation commits and test coverage.

## Threat Model and Attack Surfaces
Primary attack surfaces:
1. Unauthorized contract upgrades.
2. Unauthorized writes to DID/anchor/credential state.
3. Cross-chain or cross-contract replay on signatures.
4. Secret leakage through committed artifacts.
5. Misconfiguration risk in deployment/runbook operations.

Threat assumptions:
1. Admin keys are externally secured and rotated.
2. Public RPC endpoint integrity is standard provider trust model.
3. Production environment requires stricter operational controls than MVP baseline.

## Controls Implemented
| Control Area | Implementation | Evidence |
|---|---|---|
| Upgrade safety | UUPS with `_disableInitializers()` and role-gated `_authorizeUpgrade` | `contracts/src/shared/*.sol`, `contracts/src/trust/*.sol` |
| Access control | Role-based write paths (`REGISTRAR_ROLE`, `ANCHOR_WRITER_ROLE`, `VERIFIER_ROLE`) | `contracts/src/shared/DIDRegistry.sol`, `contracts/src/shared/VCHashAnchors.sol`, `contracts/src/trust/CredentialRegistry.sol` |
| Signature replay safety | Chain-bound digest includes domain, chain ID, and contract address | `contracts/src/base/BaseAttestationVerifier.sol` |
| Attestation validity checks | Result mismatch and expiry checks in base verifier | `contracts/src/base/BaseAttestationVerifier.sol` |
| Secret prevention | `.gitleaks.toml`, pre-commit gitleaks hook | `.gitleaks.toml`, `.pre-commit-config.yaml` |
| On-chain role wiring | Verified role grants to verifier contracts | Annex B role-check outputs |

## Findings (Open/Closed) with Severity
| ID | Finding | Severity | Status | Rationale |
|---|---|---|---|---|
| SEC-001 | Historical secret anti-patterns were present in early commit window | High | Closed | Remediated and guardrails added |
| SEC-002 | Distinct private-chain exists only as local evidence environment, not hosted production trust chain | Medium | Open | Gap reduced; production infra and controls still pending |
| SEC-003 | CCIP production trust boundaries not yet implemented | Medium | Open | Integration and validation still pending |
| SEC-004 | Operational dependency on environment correctness for fork behaviors | Low | Open | Runbook addresses this, still procedural risk |
| SEC-005 | Frontend key exposure risk if unrestricted public RPC keys used | Low | Open | Must use restricted key policy |

## Compliance Posture (Covered vs Not Covered)
Covered:
1. Technical controls and evidence for contract security fundamentals.
2. Security process controls for repository leak prevention.
3. Test-backed validation of key smart-contract safety properties.

Not fully covered:
1. Formal external compliance certification.
2. Jurisdiction-specific legal/regulatory approval.
3. Production SOC-style controls and independent audit attestation.

## Residual Risk and Ownership
| Residual Risk | Owner | Mitigation Plan |
|---|---|---|
| Private-chain deliverable incompleteness | Blockchain Lead | Implement and evidence distinct trust-chain deployment |
| CCIP workflow incompleteness | Chainlink Engineer | Deliver spec + tested implementation and runbook |
| Environment misconfiguration | DevOps Lead | Standardize env templates and CI checks |
| Frontend public key misuse | Frontend Lead | Restrict provider keys and document policy |

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________
