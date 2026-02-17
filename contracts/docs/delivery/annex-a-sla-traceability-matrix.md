# Annex A: SLA Traceability Matrix

- Document Owner: TLH Delivery Management (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Delivery | Initial SLA mapping |
| v1.0 | 2026-02-16 | TLH Delivery | Added milestone payment linkage and caveats |

## SLA Deliverable -> Repo Artifact Mapping
| SLA Deliverable | Primary Artifacts | Coverage Status |
|---|---|---|
| MVP Scope Definition Document | `contracts/docs/delivery/01-mvp-scope-definition.md` | Delivered (this package) |
| Technical Blueprint and Architecture Design | `contracts/docs/adr/*.md`, `contracts/docs/ARCHITECTURE.md` | Partial-Strong |
| Shared Anchor Chain and Private Trust Chain | `contracts/src/shared/*.sol`, `contracts/src/trust/*.sol`, `contracts/deployment-manifest.sepolia.json`, `contracts/deployment-manifest.trust-local.json` | Partial-Strong (hosted private chain pending) |
| Backend and Private Chain Implementation | `prover-api/**`, chainlink setup, contracts | Partial |
| Frontend Demo Interface | `frontend/src/**` | Partial (local delivery; acceptance/commit governance pending) |
| DID and VC Strategy Implementation | DID/VC contracts + ADR/event docs | Delivered |
| Chainlink Integration Plan (Functions, CCIP, ZK) | `chainlink-node/**`, `contracts/docs/delivery/07-ccip-integration-spec.md`, `contracts/docs/delivery/08-chainlink-functions-automation-runbook.md` | Partial |
| QA, DevOps, and Security Assessment | `contracts/docs/delivery/03-formal-qa-report.md`, `04-security-and-compliance-assessment.md`, `evidence/**` | Partial-Strong |
| VC Hash Anchors | `contracts/src/shared/VCHashAnchors.sol`, tests | Delivered |
| Project Roadmap and Sprint Plan | `contracts/docs/delivery/02-roadmap-and-sprint-plan.md` | Delivered (this package) |
| Final Deployment and Handover Documentation | `contracts/docs/delivery/05-deployment-and-handover-pack.md`, manifests/broadcast | Partial-Strong |

## Milestone Payment Clause -> Evidence Mapping (SLA 7.1)
| Milestone | SLA Coverage | Evidence | Status |
|---|---|---|---|
| M1 | setup, kickoff, initialization, foundations | repo scaffold, security remediation, architecture docs, roadmap/scope docs | Partial-Strong |
| M2 | backend/private chain setup, chainlink node, dummy API, credential schemas | `prover-api/**`, `chainlink-node/**`, contract schemas and interfaces | Partial |
| M3 | frontend, private chain integration, CCIP gateway, envelopes, automation | frontend local app, attestation envelope logic, CCIP spec/runbook docs | Partial |
| M4 | security/compliance, full QA, roadmap finalization, handover, documentation | QA report, security assessment, deployment/handover pack, annexes | Partial-Strong |

## Coverage Status Definitions
1. Delivered: Implemented and evidence-backed.
2. Partial: Implemented in part or documented without full operational completion.
3. Partial-Strong: High implementation maturity with one or more contractual closure gaps.
4. Missing: No substantive artifact.

## Notes and Caveats
1. Private trust-chain has distinct local-chain evidence (`chainId 31338`); hosted production trust-chain evidence is still pending.
2. CCIP and automation remain partial until implementation and integration tests are complete.
3. Frontend delivery should be accepted using committed and signed-off release artifacts.
4. This annex is contractual traceability support and not a legal determination.

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________
