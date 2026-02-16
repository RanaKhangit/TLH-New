# TLH Private-Chain Architecture and Operations

- Document Owner: TLH Blockchain Architecture Lead (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Blockchain | Initial private-chain closure document |
| v1.0 | 2026-02-16 | TLH Blockchain | Added strict interpretation, target topology, and validation checklist |

## Private-Chain Requirement Interpretation
Interpretation used for contractual closure:
1. A "private trust chain" requires a technically distinct chain environment from Sepolia shared anchor deployment.
2. Logical separation on one public chain is partial, not complete, for strict SLA fulfillment.
3. Completion requires chain-separation evidence and operational controls.

Current state:
1. Shared contracts remain on Sepolia for anchor/public verification paths.
2. Trust contracts were deployed to a distinct local trust chain (`chainId 31338`) as delivery evidence.
3. Production trust-chain infrastructure is still pending client infra decision.

## Chain Topology (Shared vs Trust Chain)
Target topology:
1. Shared Anchor Chain:
- DID/anchor provenance data and verification entrypoints.
2. Trust Private Chain:
- Trust-local operational credentials and local verifier updates.
3. Controlled bridge/interop layer:
- CCIP message path for trust-to-trust transfer scenarios.

Current topology (validated):
1. Shared chain: Sepolia (`chainId 11155111`) for DID/anchor verifier stack.
2. Trust chain: local dedicated chain (`chainId 31338`) for credential/trust verifier stack.
3. Role boundaries are enforced by contract-level access control on both chains.

## Infra Design and Hosting Model
Target infra model:
1. Shared anchor chain endpoint(s): stable public test/main environments.
2. Trust private chain endpoint(s): permissioned or controlled trust environment.
3. Node operations:
- Dedicated RPC
- Monitoring and alerting
- Key custody and rotation policy

Minimum hosting controls:
1. Segmented key management.
2. Access-controlled RPC exposure.
3. Backup/restore and incident response playbooks.

## Chain IDs, RPC Endpoints, and Security Boundaries
Current verified chains:
1. Sepolia chain ID `11155111`.
2. Trust-local chain ID `31338` (Anvil-backed isolated environment).
3. RPC endpoints are environment-driven and separated per deployment.

Target production private-chain metadata (required for final closeout):
1. Private chain ID.
2. RPC URL and authentication model.
3. Access policy and trust boundary definition.
4. Bridge source/destination allowlist policy.

## Deployment Evidence and Validation Steps
Current evidence:
1. `contracts/deployment-manifest.sepolia.json`
2. `contracts/broadcast/DeploySepolia.s.sol/11155111/run-latest.json`
3. `contracts/deployment-manifest.trust-local.json`
4. `contracts/broadcast/DeployTrustChainLocal.s.sol/31338/run-latest.json`
5. `contracts/broadcast/TransferRolesToMultisig.s.sol/31338/run-latest.json`
6. Fork behavior tests in `contracts/test/fork/*.sol`

Required additional evidence for production private-chain closure:
1. Hosted non-local trust chain deployment manifest and tx receipts.
2. Role and wiring checks on hosted trust chain endpoints.
3. End-to-end shared-to-trust transfer evidence in hosted topology.
4. Operational runbook execution evidence with incident drill outputs.

Validation checklist (MVP private-chain evidence complete):
1. Distinct chain ID confirmed.
2. Trust contracts deployed and verifiable.
3. Required role grants and signer setup complete.
4. Integration tests pass on separated topology.

Validation status (2026-02-16):
1. Distinct chain ID confirmed: Complete (`31338` vs `11155111`).
2. Trust contracts deployed and verifiable: Complete (manifest + broadcast evidence).
3. Required role grants and signer setup complete: Complete (deployment bootstrap + role checks).
4. Hosted production trust chain: Pending client infra selection.

## Operational Responsibilities
| Responsibility | Owner | Notes |
|---|---|---|
| Chain provisioning and security baseline | Blockchain Lead | Includes network and RPC hardening |
| Deployment and upgrade operations | DevOps and Smart Contract Engineer | UUPS and role control process |
| Monitoring and incident response | DevOps | Must include alert thresholds |
| Access governance and key custody | Security Lead + Client Admin | Formal handover required |

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________
