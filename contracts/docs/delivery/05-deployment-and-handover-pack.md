# TLH Final Deployment and Handover Pack

- Document Owner: TLH DevOps and Delivery (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH DevOps | Initial handover pack |
| v1.0 | 2026-02-16 | TLH DevOps | Added deployment inventory, runbook, and ownership transfer checklist |

## System Overview and Component Map
Core components:
1. Prover API (`prover-api/`) for verification services.
2. Chainlink node and external adapter (`chainlink-node/`) for orchestration and tx submission.
3. Smart contracts (`contracts/src/`) split by shared and trust domains.
4. Frontend demo interface (`frontend/`) for operator/demo interaction.

Reference architecture:
- `contracts/docs/ARCHITECTURE.md`
- `contracts/docs/adr/*.md`

## Contract Addresses and Network Inventory
Source of truth:
- `contracts/deployment-manifest.sepolia.json`
- `contracts/broadcast/DeploySepolia.s.sol/11155111/run-latest.json`
- `contracts/deployment-manifest.trust-local.json`
- `contracts/broadcast/DeployTrustChainLocal.s.sol/31338/run-latest.json`

Network:
- Chain ID: `11155111`
- Network: `sepolia`
- Deployer/Admin: `0x3B50966A8B71f277e90e14cdC31455F6Af3977e6`

Trust-chain evidence network:
- Chain ID: `31338`
- Network: `trust-local`
- Deployer/Admin: `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266`

Contracts:
1. DIDRegistry proxy: `0x6c6fa7f93860f16a1dfdd60ca3b83b703c597a0a`
2. VCHashAnchors proxy: `0x95d02ae28d6fa86f67f121ba36d9cbd363aafc68`
3. CredentialRegistry proxy: `0xae4b71776fab8e431cee4874ad3a2a97588d89fb`
4. TrustAttestationVerifier proxy: `0x2ad7540b14585ebfb3c86604d1927b40e2efa5db`
5. AttestationVerifier proxy: `0xce863e465f21df87ad9f0a2af838fac1750f08d2`

Trust-chain contracts (isolated evidence deployment):
1. CredentialRegistry proxy: `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0`
2. TrustAttestationVerifier proxy: `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9`

## Deployment Steps and Prerequisites
Prerequisites:
1. Foundry toolchain installed and verified.
2. Valid `SEPOLIA_RPC_URL` and deployment private key.
3. Admin address configured for role ownership.

Deployment command path:
1. Use `contracts/script/DeploySepolia.s.sol`
2. Execute script against Sepolia with required env vars.
3. Keep `BOOTSTRAP_ROLES=true` to apply runtime grants during deployment.
4. If `ADMIN_ADDRESS` differs from deployer, provide `ADMIN_PRIVATE_KEY`.
5. Provide `ATTESTATION_SIGNER` to initialize signer whitelists.
6. Generate and verify manifest consistency.

Post-deploy verification:
1. Validate proxy implementation slots.
2. Validate role assignments (`REGISTRAR_ROLE`, `ANCHOR_WRITER_ROLE`, `VERIFIER_ROLE`).
3. Validate signer whitelists on both verifier contracts.
4. Validate dependency wiring:
- `AttestationVerifier.didRegistry()`
- `AttestationVerifier.vcHashAnchors()`
- `TrustAttestationVerifier.credentialRegistry()`

## Ops Runbook (Start/Stop/Monitor/Recover)
Start:
1. Start prover API (`npm run dev` in `prover-api`).
2. Start external adapter (`npm run dev` in `chainlink-node/external-adapter`).
3. Start Chainlink node (`docker compose up -d` in `chainlink-node`).
4. Start frontend (`npm run dev` in `frontend`).

Stop:
1. Stop frontend/prover/adapter processes.
2. Stop chainlink services (`docker compose down`).

Monitor:
1. Prover API health endpoint.
2. External adapter health endpoint.
3. Chainlink node UI and job execution.
4. On-chain tx and event monitoring on Sepolia.

Recover:
1. Verify environment variables and provider availability.
2. Reconcile role grants and signer whitelist states.
3. Re-run core and fork verification tests.
4. Re-deploy only if manifest and state recovery fail.

## Backup/Rollback/Upgrade Procedure
Backup:
1. Preserve deployment manifest and broadcast artifacts.
2. Preserve current implementation addresses and tx hashes.
3. Preserve role snapshot before governance transfer.

Rollback:
1. If upgrade introduces regressions, upgrade proxy back to previous known-safe implementation.
2. Re-run contract and fork validation suites after rollback.

Upgrade:
1. Deploy new implementation.
2. Execute role-authorized UUPS upgrade.
3. Validate storage compatibility and smoke tests.
4. Prefer multisig execution for all upgrade actions.

Governance migration:
1. Execute `contracts/script/TransferRolesToMultisig.s.sol` to grant admin/upgrader roles to multisig.
2. Optionally set `REVOKE_OLD_ADMIN=true` after multisig verification.
3. Script supports partial target sets, enabling trust-only migration in isolated trust chains.
4. Sepolia governance migration is pending client-provided multisig destination and admin authorization.

## Access Transfer and Ownership Handover Checklist
| Item | Status | Notes |
|---|---|---|
| Admin key holder identified | Pending formal signoff | Current admin is deployer address in manifest |
| Role owner mapping documented | Complete | Refer to Annex B and architecture docs |
| Operational credentials transfer process | Pending formal signoff | Must be client-approved and timestamped |
| Runbook handover session | Pending | Schedule with client stakeholders |
| Acceptance confirmation recorded | Pending | Written approval required |

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________
