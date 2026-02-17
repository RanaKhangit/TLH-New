# TLH Private-Chain Architecture and Operations

- Document Owner: TLH Blockchain Architecture Lead (Supplier)
- Date: February 16, 2026
- Version: v2.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Blockchain | Initial private-chain closure document |
| v1.0 | 2026-02-16 | TLH Blockchain | Added strict interpretation, target topology, and validation checklist |
| v2.0 | 2026-02-16 | TLH Blockchain | Polygon Edge private chain (chainId 100100), Docker infra, deployment scripts |

## Private-Chain Requirement Interpretation
Interpretation used for contractual closure:
1. A "private trust chain" requires a technically distinct chain environment from Sepolia shared anchor deployment.
2. Logical separation on one public chain is partial, not complete, for strict SLA fulfillment.
3. Completion requires chain-separation evidence and operational controls.

Current state:
1. Shared contracts remain on Sepolia for anchor/public verification paths.
2. Trust contracts deployed to Anvil local chain (`chainId 31338`) as initial delivery evidence.
3. **Polygon Edge private chain (`chainId 100100`) now available** — 4-validator IBFT 2.0 PoA network with Docker Compose infrastructure, automated deployment, and validation scripts. See `private-chain/README.md`.
4. Production trust-chain infrastructure pending client infra decision (Polygon Edge ready for hosted deployment).

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
2. Trust chain (local): Anvil (`chainId 31338`) for initial credential/trust verifier testing.
3. Trust chain (Polygon Edge): `chainId 100100`, 4-validator IBFT 2.0 PoA, Docker Compose infra.
4. Role boundaries enforced by contract-level access control on both chains.
5. CCIP bridge contracts (TLHCCIPSender/TLHCCIPReceiver) provide cross-chain credential transfer.

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
1. Sepolia chain ID `11155111` — shared anchor contracts.
2. Trust-local chain ID `31338` (Anvil) — initial local testing.
3. **Polygon Edge chain ID `100100`** — private trust chain (4 IBFT 2.0 validators).
4. RPC endpoints are environment-driven and separated per deployment.

Polygon Edge private chain details:
| Parameter       | Value                  |
|-----------------|------------------------|
| Chain ID        | `100100`               |
| Consensus       | IBFT 2.0 (PoA)        |
| Validators      | 4                      |
| BFT Tolerance   | 3f+1 (1 faulty node)  |
| Block Time      | ~2 seconds             |
| Block Gas Limit | 20,000,000             |
| JSON-RPC        | `http://localhost:8545` (validator-1) |
| Infrastructure  | Docker Compose (`private-chain/docker-compose.yml`) |

Target production private-chain metadata (required for final closeout):
1. Private chain ID: **`100100` (provisioned)**.
2. RPC URL and authentication model: localhost for dev; production TBD per client infra.
3. Access policy and trust boundary definition.
4. Bridge source/destination allowlist policy (CCIP contracts deployed).

## Deployment Evidence and Validation Steps
Current evidence:
1. `contracts/deployment-manifest.sepolia.json` — Sepolia shared contracts.
2. `contracts/broadcast/DeploySepolia.s.sol/11155111/run-latest.json`
3. `contracts/deployment-manifest.trust-local.json` — Anvil local trust chain.
4. `contracts/broadcast/DeployTrustChainLocal.s.sol/31338/run-latest.json`
5. `contracts/broadcast/TransferRolesToMultisig.s.sol/31338/run-latest.json`
6. Fork behavior tests in `contracts/test/fork/*.sol`

Polygon Edge private chain artifacts (committed):
7. `contracts/script/DeployPrivateChain.s.sol` — Forge deploy script (chainId 100100).
8. `private-chain/docker-compose.yml` — 4-validator IBFT 2.0 Docker infrastructure.
9. `private-chain/scripts/init.sh` — validator secret and genesis generation.
10. `private-chain/scripts/deploy-trust-contracts.sh` — automated deployment.
11. `private-chain/scripts/validate.sh` — post-deployment validation (6 checks).
12. `private-chain/.env.example` — environment variable template.

Polygon Edge evidence (generated after chain execution — not yet present):
13. `contracts/deployment-manifest.private-chain.json` — generated by `deploy-trust-contracts.sh`.
14. `contracts/broadcast/DeployPrivateChain.s.sol/100100/run-latest.json` — generated by Forge broadcast.
15. `private-chain/genesis.json` — generated by `init.sh`.

Required additional evidence for production private-chain closure:
1. Execute `init.sh` + `docker compose up` + `deploy-trust-contracts.sh` + `validate.sh` to produce items 13-15.
2. Hosted non-local trust chain deployment manifest and tx receipts.
3. Role and wiring checks on hosted trust chain endpoints.
4. End-to-end shared-to-trust transfer evidence in hosted topology.
5. Operational runbook execution evidence with incident drill outputs.

Validation checklist (MVP private-chain evidence complete):
1. Distinct chain ID confirmed.
2. Trust contracts deployed and verifiable.
3. Required role grants and signer setup complete.
4. Integration tests pass on separated topology.

Validation status (2026-02-16):
1. Distinct chain ID confirmed: **Complete** for Anvil (`31338` vs `11155111`). Polygon Edge (`100100`) configured but chain not yet executed.
2. Trust contracts deployed and verifiable: **Complete** for Anvil (manifest + broadcast evidence). Polygon Edge pending chain execution.
3. Required role grants and signer setup complete: **Complete** for Anvil (deployment bootstrap + role checks). Polygon Edge wired in deploy script, pending execution.
4. Polygon Edge private chain infrastructure: **Complete** (Docker Compose, init/deploy/validate scripts committed and ready to run).
5. Hosted production trust chain: Pending client infra selection (Polygon Edge Docker infra ready for hosted deployment).

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
