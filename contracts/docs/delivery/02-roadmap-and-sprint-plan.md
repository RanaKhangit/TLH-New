# TLH Project Roadmap and Sprint Plan

- Document Owner: TLH Delivery Management (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Delivery | Initial roadmap and sprint structure |
| v1.0 | 2026-02-16 | TLH Delivery | Added dependencies, risks, and DoD gates |

## Milestones M1-M4 with Target Dates
Contractual windows (SLA):
- M1 Discovery and Setup: Weeks 1-3
- M2 Core Development: Weeks 4-12
- M3 Integration and Frontend: Weeks 13-16
- M4 QA, Security Review, Deployment: Weeks 17-18

Proposed closure schedule from current baseline date (2026-02-16):
| Milestone | Target Window | Primary Outcome |
|---|---|---|
| M1 Closeout | 2026-02-17 to 2026-02-21 | Finalize scope/blueprint package and signoff |
| M2 Closeout | 2026-02-17 to 2026-02-24 | Finalize chain architecture evidence and private-chain plan |
| M3 Delivery | 2026-02-24 to 2026-03-14 | Frontend packaging, CCIP spec/implementation milestone, integration proof |
| M4 Delivery | 2026-03-14 to 2026-03-28 | Formal QA/compliance docs, handover package, acceptance cycle |

## Sprint Breakdown (Tasks, Owners, Estimates)
| Sprint | Dates | Key Tasks | Owner | Estimate |
|---|---|---|---|---|
| S1 Documentation Closure | 2026-02-17 to 2026-02-21 | Deliver docs 01-05 and annexes | Delivery Lead + Tech Lead | 5 days |
| S2 Chain Completion | 2026-02-21 to 2026-02-28 | Distinct private-chain architecture and deployment plan | Blockchain Lead | 5 days |
| S3 Integration Completion | 2026-02-28 to 2026-03-10 | CCIP path and automation runbook/implementation gates | Blockchain + Chainlink Engineer | 7 days |
| S4 Acceptance and Handover | 2026-03-10 to 2026-03-28 | Formal QA/compliance signoff and handover | QA Lead + PM | 10 days |

## Dependency Map
| Dependency | Needed For | Type | Owner |
|---|---|---|---|
| SLA acceptance criteria confirmation | Milestone closeout | Client decision | Client Representative |
| RPC and Chainlink environment availability | Integration and fork validation | External technical | Engineering |
| Contract roles and signer governance | End-to-end behavior tests | Operational | Admin/DevOps |
| Private-chain infra selection | Strict SLA closure for private chain | Architecture decision | Blockchain Lead |
| CCIP route definition | M3 completion | Design and infra | Chainlink Engineer |

## Critical Path
1. Scope and acceptance lock for documentation package.
2. Private-chain architecture decision and deployment evidence.
3. CCIP integration completion with tested message flow.
4. Formal QA/compliance assessment publication.
5. Final deployment and handover sign-off.

## Risks and Mitigations
| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Ambiguity in private-chain interpretation | Medium | High | Use strict interpretation and produce explicit chain-separation evidence |
| CCIP implementation delays | Medium | High | Stage delivery: spec first, minimal viable implementation second |
| Environment drift causing fork-test instability | Medium | Medium | Pin fork blocks and document env prerequisites |
| Missing client approvals within review window | Medium | High | Weekly checkpoint and written acceptance requests |
| Secrets/config inconsistency across tools | Medium | Medium | Standardized `.env.example`, runbook checks, and gitleaks guardrails |

## Definition of Done Per Sprint
| Sprint | Definition of Done |
|---|---|
| S1 | All required documents exist, include metadata/history/sign-off sections, and map to SLA clauses |
| S2 | Private-chain architecture/ops doc complete with deploy and validation checklist |
| S3 | CCIP/automation deliverables include schema, failure handling, and test scenarios with evidence |
| S4 | QA/compliance/handover documents finalized and prepared for acceptance review |

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________

