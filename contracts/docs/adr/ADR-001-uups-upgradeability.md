# ADR-001 — UUPS Proxy Upgradeability Pattern

## Status
Accepted

## Context
Trust Layer Health (TLH) requires smart contracts that can evolve as the protocol matures, while maintaining strong governance controls, verifiability, and operational safety. Upgradeability is required to:
- Fix bugs and security issues without redeploying an entirely new system
- Add features across milestones (M1→M5) while preserving on-chain state
- Maintain clear governance evidence and auditability for every change

The upgrade mechanism must be:
- Standardised, widely audited, and well-supported by tooling
- Explicitly governed (no ad-hoc upgrades)
- Compatible with Foundry testing and static analysis (Slither)
- Safe by default with strict authorization

## Decision
All TLH contracts requiring upgradeability MUST use **OpenZeppelin UUPSUpgradeable** (ERC-1822 / ERC-1967) via **UUPS proxies**.

Each upgradeable contract MUST:
- Use `UUPSUpgradeable` and `AccessControlUpgradeable`
- Use initializer functions only (no constructors for state setup)
- Include a `_disableInitializers()` constructor on every **concrete** (non-abstract) implementation contract to prevent direct initialization of the implementation behind the proxy:
  ```solidity
  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() { _disableInitializers(); }
  ```
  Abstract base contracts that are never deployed directly SHOULD document this requirement for their children instead.
- Implement `_authorizeUpgrade(address newImplementation)` restricted to `onlyRole(UPGRADER_ROLE)`
- Include a storage gap pattern: `uint256[50] private __gap;` (or consistent equivalent) in every upgradeable base and implementation contract
- Avoid storage layout breaks (append-only changes; no re-ordering/removal)
- Maintain an ADR record for every upgrade (see Governance)

## Upgrade Authorization Model
### Roles
- `DEFAULT_ADMIN_ROLE`: assigned to a **multisig** (not an EOA)
- `UPGRADER_ROLE`: assigned to the same multisig (or a dedicated upgrade multisig)

### Rules
- Only `UPGRADER_ROLE` may authorize an upgrade
- No upgrades are executed by EOAs in production environments
- Upgrade actions must be recorded (tx hash, implementation address, proxy address, and linked ADR entry)

### Reference Implementation
- OpenZeppelin: `UUPSUpgradeable`
- OpenZeppelin: `AccessControlUpgradeable`

## Alternatives Considered
### 1) Transparent Proxy (OpenZeppelin)
Pros:
- Familiar pattern; admin separation
Cons:
- Additional admin surface area and operational complexity
- Slightly heavier and less direct than UUPS for our governance model

### 2) Beacon Proxy
Pros:
- Upgrade multiple proxies via one beacon
Cons:
- Not required for M1 scope; increases complexity
- Riskier blast radius if beacon is compromised

### 3) Diamond (EIP-2535)
Pros:
- Highly modular
Cons:
- Complexity is excessive for TLH M1–M3
- Higher audit and operational overhead

### 4) No Upgradeability
Pros:
- Simplest security model
Cons:
- Not compatible with TLH milestone-driven delivery, evolving workflows, and governance requirements

## Consequences
### Positive
- Standardized and audited upgrade path
- Strong role-based control over upgrades
- Clear governance story for auditors and stakeholders

### Negative / Risks
- Upgradeability introduces additional attack surface (upgrade auth must be secured)
- Storage layout discipline is mandatory
- Requires robust testing and static analysis gates (CI + Slither)

## Governance Requirements
- Every upgrade MUST be associated with an ADR entry (new ADR or addendum) documenting:
  - Reason for upgrade
  - Change summary
  - Risk analysis
  - Test evidence and CI artifacts
  - Deployment/upgrade transaction hashes
- No upgrade may be executed without recorded governance approval (multisig execution + ADR reference)

## Impact on Milestones
- M1 contracts will be implemented using UUPS patterns from day one
- Deployment scripts must deploy proxy + implementation and wire roles correctly
- CI will enforce tests and security scanning before merge
