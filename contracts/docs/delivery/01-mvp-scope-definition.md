# TLH MVP Scope Definition Document

- Document Owner: TLH Engineering and Delivery (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Engineering | Initial SLA-aligned scope baseline |
| v1.0 | 2026-02-16 | TLH Engineering | Added acceptance criteria and change-control process |

## Objective and Business Outcome
The MVP must deliver verifiable healthcare credential attestation workflows that are pilot-ready for Trust Layer Health. The business outcome is a functioning end-to-end system where verified attestations can be anchored, queried, and operationally consumed with auditable records.

Scope and payment alignment are governed by:
- `Project info/SLA for Chad Donahue (MPV Development) .pdf` (Sections 3.1 and 7.1)

## In-Scope Features (Explicit List)
1. Chainlink-node based DECO verification flow and external adapter integration.
2. Backend prover API for attestation verification and supporting demo lookups.
3. Shared anchor smart-contract layer:
- `contracts/src/shared/DIDRegistry.sol`
- `contracts/src/shared/VCHashAnchors.sol`
- `contracts/src/shared/AttestationVerifier.sol`
4. Trust-chain smart-contract layer:
- `contracts/src/trust/CredentialRegistry.sol`
- `contracts/src/trust/TrustAttestationVerifier.sol`
5. Shared verification logic:
- `contracts/src/base/BaseAttestationVerifier.sol`
6. Interface contracts:
- `contracts/src/interfaces/*.sol`
7. UUPS upgradeability, role-based access control, and hardening controls.
8. Contract unit and fork behavior test suites:
- `contracts/test/**/*.sol`
9. Sepolia deployment artifacts and manifest:
- `contracts/script/DeploySepolia.s.sol`
- `contracts/broadcast/DeploySepolia.s.sol/11155111/run-latest.json`
- `contracts/deployment-manifest.sepolia.json`
10. Architecture and ADR documentation:
- `contracts/docs/adr/*.md`
- `contracts/docs/ARCHITECTURE.md`
- `contracts/docs/event-schema.md`
11. Frontend demo interface (current local delivery, pending commit/governance acceptance):
- `frontend/src/**`

## Out-of-Scope Features
1. Production launch approvals and legal signoff.
2. Formal regulatory certification by external auditors.
3. Multi-trust production CCIP rollout.
4. Operational 24x7 managed support contract.
5. Any SLA expansion not explicitly approved under written variation.

## Assumptions and Dependencies
1. Client provides timely approvals under SLA review windows.
2. Required third-party services remain reachable (RPC providers, Chainlink infra, hosted APIs).
3. Secure secrets management remains outside git-tracked files.
4. Distinct private trust-chain environment is still required for strict completion of that deliverable.
5. Acceptance requires document review plus evidence validation, not only code presence.

## Acceptance Criteria Per Scope Item
| Scope Item | Acceptance Criteria | Evidence |
|---|---|---|
| Backend and Chainlink flow | Prover API and adapter run with documented commands | `prover-api/src/server.ts`, `chainlink-node/external-adapter/src/index.ts`, `START-HERE.md` |
| Shared and trust contracts | Contracts compile and deploy with manifest evidence | `contracts/src/**/*.sol`, `contracts/deployment-manifest.sepolia.json` |
| Testing | Contract tests pass in defined environment | `evidence/qa/unit-test-results.txt` and fork test commands |
| Security hardening | No active tracked secret leaks and role/upgrade controls present | `.gitleaks.toml`, `.pre-commit-config.yaml`, contract role checks |
| Deployment | Proxy and implementation addresses plus tx hashes documented | `contracts/deployment-manifest.sepolia.json`, broadcast JSON |
| Documentation | ADR + architecture + delivery docs reviewed and accepted | `contracts/docs/**` |

## Change-Control Process
1. Raise a Change Request (CR) with requested scope delta and justification.
2. Map CR impact to SLA deliverables, milestone payments, and timeline.
3. Obtain written approval from Client and Supplier representatives.
4. Record approved CR in this document's version history and annex traceability updates.
5. Re-baseline sprint plan and acceptance criteria in `02-roadmap-and-sprint-plan.md`.

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________

