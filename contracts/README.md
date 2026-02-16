# TLH Contracts

## Prerequisites
1. Foundry installed (`forge --version`).
2. Environment variables:
- `SEPOLIA_RPC_URL`: RPC endpoint for fork/state tests.
- `DEPLOYER_PRIVATE_KEY`: deploy key for scripts.
- `ADMIN_ADDRESS`: admin address for proxy initialization.
- `SIGNER_PK`: signer key for behavior fork tests.
- `FORK_BLOCK`: pinned Sepolia block for deterministic behavior suites.

## Quick Start
From repo root:

```bash
cd contracts
forge build
```

## Test Commands
Unit + local suites (no RPC required):

```bash
forge test --skip test/ccip/** --skip src/ccip/** --no-match-path "test/fork/*" --no-match-contract ".*Fork.*"
```

Sepolia state fork suites (RPC required):

```bash
forge test --skip test/ccip/** --skip src/ccip/** --match-contract ".*Fork.*"
```

Sepolia behavior suites (RPC + signer + fork block required):

```bash
forge test --skip test/ccip/** --skip src/ccip/** --match-path "test/fork/*.sol"
```

Full test run:

```bash
forge test --skip test/ccip/** --skip src/ccip/**
```

Note:
1. `test/ccip/**` and `src/ccip/**` are intentionally excluded in this stabilization stream.
2. CCIP implementation/testing is tracked as a separate workstream.

## Deployment
Deploy contracts and (optionally) bootstrap runtime roles/signers:

```bash
forge script script/DeploySepolia.s.sol:DeploySepolia --rpc-url $SEPOLIA_RPC_URL --broadcast
```

Deploy trust-only contracts on isolated local chain evidence environment (`chainId 31338`):

```bash
forge script script/DeployTrustChainLocal.s.sol:DeployTrustChainLocal --rpc-url http://127.0.0.1:8545 --broadcast
node tools/make-manifest-trust-local.js
```

Optional deploy-time env flags:
1. `BOOTSTRAP_ROLES` (`true`/`false`, default `true`)
2. `ATTESTATION_SIGNER` (address added to both verifier signer whitelists)
3. `ADMIN_PRIVATE_KEY` (required when `ADMIN_ADDRESS` differs from deployer)

### Governance Migration (EOA -> Multisig)
Use `script/TransferRolesToMultisig.s.sol` with:
1. `ADMIN_PRIVATE_KEY` (current admin key)
2. `MULTISIG_ADDRESS`
3. Optional `DID_REGISTRY_PROXY`
4. Optional `VC_HASH_ANCHORS_PROXY`
5. Optional `CREDENTIAL_REGISTRY_PROXY`
6. Optional `ATTESTATION_VERIFIER_PROXY`
7. Optional `TRUST_ATTESTATION_VERIFIER_PROXY`
8. Optional `REVOKE_OLD_ADMIN=true` to remove old admin roles after transfer
9. At least one proxy variable must point to a deployed contract

## Structure
- `src/interfaces/` - shared interfaces
- `src/base/` - base contracts
- `src/shared/` - shared anchor chain contracts
- `src/trust/` - trust private chain contracts
- `test/` - Foundry tests
- `docs/adr/` - Architecture Decision Records
