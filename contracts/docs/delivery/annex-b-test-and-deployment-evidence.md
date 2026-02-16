# Annex B: Test and Deployment Evidence

- Document Owner: TLH Engineering QA and DevOps (Supplier)
- Date: February 16, 2026
- Version: v1.0
- Status: Draft for Client Review

## Version History
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | 2026-02-16 | TLH Engineering | Initial evidence annex |
| v1.0 | 2026-02-16 | TLH Engineering | Added tx receipts, role checks, and build/lint evidence |

## Test Command Outputs
### Solidity Test Evidence
Historical artifact:
1. `evidence/qa/unit-test-results.txt`
2. Result: 104 tests passed, 0 failed, 0 skipped.

Latest full run (with fork env configured, 2026-02-16):
1. Command: `forge test --skip test/ccip/** --skip src/ccip/**`
2. Result: 134 tests passed, 0 failed, 0 skipped.
3. Includes:
- Unit suites for base/shared/trust contracts.
- Fork state suites.
- Fork behavior suites (`contracts/test/fork/*.sol`).

### Frontend Build and Lint Evidence (2026-02-16)
Build:
1. Command: `npm run build` in `frontend/`
2. Result: success; static routes generated for `/`, `/attestations`, `/credentials`, `/did`, `/verify`.

Lint:
1. Command: `npm run lint` in `frontend/`
2. Result: success with zero warnings and zero errors.

## Broadcast/Manifest/Tx Hashes
Primary evidence files:
1. `contracts/deployment-manifest.sepolia.json`
2. `contracts/broadcast/DeploySepolia.s.sol/11155111/run-latest.json`
3. `contracts/deployment-manifest.trust-local.json`
4. `contracts/broadcast/DeployTrustChainLocal.s.sol/31338/run-latest.json`
5. `contracts/broadcast/TransferRolesToMultisig.s.sol/31338/run-latest.json`

Deployment receipt verification (Sepolia):
| Contract | Tx Type | Tx Hash | Receipt Status | Block |
|---|---|---|---|---:|
| DIDRegistry | impl | `0xef57c1d91b6f7cbf460b5644b91765d67354e992af3ff97ffdab69e7e0bcf940` | `0x1` | 10260088 |
| DIDRegistry | proxy | `0x617557c8b6be40e7f25a87c045c86472e81bee396fe3674ec0d56c529fbde6d0` | `0x1` | 10260089 |
| VCHashAnchors | impl | `0xe6db0d9d20305ffa366e4d1e5632a10dc3ab7ee57f33ca7adec90cf068e45701` | `0x1` | 10260088 |
| VCHashAnchors | proxy | `0xedcae89621fe79eae7ee539ab741edd3efe213d0b4e3b9f531d28ccd3a913d61` | `0x1` | 10260089 |
| CredentialRegistry | impl | `0x268644086f921a103aed84d9a5dca455b4d2fc141b47b2d4474ec5752446f21a` | `0x1` | 10260088 |
| CredentialRegistry | proxy | `0xa115ffc9e5ef06f078a70df7cd2dceca7f29389b7b20f5226233d2f8b84e929a` | `0x1` | 10260089 |
| TrustAttestationVerifier | impl | `0x1d7f80de5e1defbed454c95400b7a1f51c21098b015204e030a92385db59d174` | `0x1` | 10260089 |
| TrustAttestationVerifier | proxy | `0xd1ad3f557709cfefaa567ddc4d400939b0bbfc4bc7786f1a15a25e2391b6e8e7` | `0x1` | 10260089 |
| AttestationVerifier | impl | `0x0c98d44b7c9ffc3b4e4d3a607333751799b92b749bba697d258cf331a429fa14` | `0x1` | 10260089 |
| AttestationVerifier | proxy | `0x6f320f87bd26e085013d9b815c38e0bae4c9f2d93409e698b9a58e1cdce39d24` | `0x1` | 10260089 |

Trust-local deployment receipts (`chainId 31338`):
| Contract | Tx Type | Tx Hash | Receipt Status | Block |
|---|---|---|---|---:|
| CredentialRegistry | impl | `0xb911a9ccc0d407e558377b04f6f08320d78cf3f18e7974374fba8497a2643a99` | `0x1` | 4 |
| CredentialRegistry | proxy | `0x253f79da6e2e62a688a3d50480bd10fcef787bfac8669279626d1ff5e2b50980` | `0x1` | 4 |
| TrustAttestationVerifier | impl | `0x2afad70d6d4a0235fa3c125486ee39e67868085e3dcd3da5a15f982ad6a4b67a` | `0x1` | 3 |
| TrustAttestationVerifier | proxy | `0x3ec231c73bada03d6b81125a772c9640e1a38493c7fcd26e4f6a2675404f851f` | `0x1` | 3 |
| TransferRolesToMultisig | first role-grant tx | `0x1d8ab47a2ba3bef452261ed8f0de93d54e9f877c0b666a7db54312f83f5c90c2` | `0x1` | 5 |

## On-Chain Role/Wiring Checks
Role checks (2026-02-16):
1. `DID REGISTRAR->AV=true`
2. `VCA WRITER->AV=true`
3. `CR VERIFIER->TAV=true`

Dependency wiring checks:
1. `AttestationVerifier.didRegistry()` -> `0x6C6fA7f93860F16A1dFDD60Ca3B83b703C597a0A`
2. `AttestationVerifier.vcHashAnchors()` -> `0x95D02Ae28D6fa86f67F121bA36d9cbD363AaFc68`
3. `TrustAttestationVerifier.credentialRegistry()` -> `0xaE4B71776Fab8E431ceE4874Ad3a2a97588D89FB`

Proxy implementation slot checks (EIP-1967 storage slot):
1. DIDRegistry: match = true
2. VCHashAnchors: match = true
3. CredentialRegistry: match = true
4. TrustAttestationVerifier: match = true
5. AttestationVerifier: match = true

Trust-local governance rehearsal checks (`multisig=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`):
1. CredentialRegistry `DEFAULT_ADMIN_ROLE`: true
2. CredentialRegistry `ADMIN_ROLE`: true
3. CredentialRegistry `UPGRADER_ROLE`: true
4. TrustAttestationVerifier `DEFAULT_ADMIN_ROLE`: true
5. TrustAttestationVerifier `SIGNER_ADMIN_ROLE`: true
6. TrustAttestationVerifier `UPGRADER_ROLE`: true

## Build/Lint Outputs
Build output summary:
1. Next.js build succeeded with static app routes.
2. No build-time errors.

Lint output summary:
1. ESLint completed.
2. Zero warnings and zero errors.

## Evidence Timestamps
| Evidence Type | Date |
|---|---|
| Solidity full test run (`forge test`) | 2026-02-16 |
| Deployment receipt verification | 2026-02-16 |
| Role and wiring checks | 2026-02-16 |
| Frontend build and lint | 2026-02-16 |
| Trust-local deployment and governance rehearsal | 2026-02-16 |
| Historical QA artifact (`evidence/qa/unit-test-results.txt`) | 2026-02-16 file timestamp |

## Sign-Off
- Prepared By: ____________________
- Reviewed By: ____________________
- Approved By: ____________________
