# ADR-004 — Chainlink CCIP Cross-Chain Credential Transfer

## Status
Accepted

## Context
Trust Layer Health (TLH) operates across multiple EVM chains. Credentials written on a Trust chain (e.g. Arbitrum Sepolia) need to be bridged to the Anchor chain (Ethereum Sepolia) where the canonical CredentialRegistry lives. The SLA requires "Chainlink Integration Plan (Functions, CCIP, ZK workflows)" (deliverable #7) and M3 specifically calls for "CCIP gateway setup".

Requirements:
- Cross-chain credential transfer from Trust chain to Anchor chain
- Replay protection (no duplicate writes from the same source message)
- Access-controlled: only authorized senders/receivers
- Compatible with the existing UUPS proxy pattern (ADR-001)
- Testable locally without live CCIP infrastructure

## Decision
We implement two new UUPS-upgradeable contracts using Chainlink CCIP:

### TLHCCIPSender (Trust chain)
- Reads credentials and sends them cross-chain via the CCIP Router
- Pays fees in native ETH (`feeToken = address(0)`)
- Maintains per-destination monotonic nonces for replay protection
- Dual allowlisting: destination chain + receiver address must be configured
- SENDER_ROLE gates who can trigger sends

### TLHCCIPReceiver (Anchor chain)
- Receives CCIP messages and writes credentials to the local CredentialRegistry
- Implements `ICCIPReceiver` directly (NOT inheriting `CCIPReceiver` base — see Alternatives)
- Dual allowlisting: source chain + sender address must match
- Sequential nonce validation: message nonce must equal lastNonce (no gaps, no replays)
- Holds VERIFIER_ROLE on the CredentialRegistry

### Payload Format (CCIP_TLH_V1)
```solidity
abi.encode(
    keccak256("CCIP_TLH_V1"),  // protocolVersion (bytes32)
    nonce,                      // uint256 — monotonic per-destination
    subjectDID,                 // bytes32
    predicateType,              // bytes32
    valid,                      // bool
    expiresAt,                  // uint256
    attestationId               // bytes32
)
```

The protocol version tag enables future payload evolution without breaking existing contracts.

### Architecture
```
Trust Chain (Arbitrum Sepolia)           Anchor Chain (Ethereum Sepolia)
┌─────────────────────────┐              ┌─────────────────────────┐
│  CredentialRegistry     │              │  CredentialRegistry     │
│          │              │              │          ▲              │
│          ▼              │              │          │              │
│  TLHCCIPSender          │   CCIP msg   │  TLHCCIPReceiver        │
│  - reads credential     │ ──────────►  │  - validates allowlists │
│  - constructs payload   │              │  - checks nonce         │
│  - pays fee (native)    │              │  - writes credential    │
│  - increments nonce     │              │                         │
└─────────────────────────┘              └─────────────────────────┘
```

## CCIP Constants

| Chain | Router Address | Chain Selector |
|-------|---------------|----------------|
| Ethereum Sepolia | `0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59` | `16015286601757825753` |
| Arbitrum Sepolia | `0x2a9C5afb0d0e86603169DdbD7836e478b4624789` | `3478487238524512106` |

## Security Model

1. **Replay protection**: Monotonic nonces per source chain (receiver rejects any nonce != expected)
2. **Access control**: Sender requires SENDER_ROLE; Receiver validates source chain + sender address allowlists
3. **Router validation**: Only the configured CCIP Router can call `ccipReceive()`
4. **Protocol versioning**: Receiver rejects messages with mismatched protocol version
5. **UUPS authorization**: Only UPGRADER_ROLE can upgrade either contract
6. **Fee refund**: Sender refunds excess ETH to the caller after CCIP fee deduction

## Alternatives Considered

### 1. Inherit CCIPReceiver base contract
**Rejected.** Chainlink's `CCIPReceiver` uses an `immutable` router address set in the constructor, which conflicts with the UUPS proxy pattern where the constructor must only call `_disableInitializers()`. Additionally, it imports `@openzeppelin/contracts@5.0.2` (non-upgradeable), causing version conflicts with our `@openzeppelin/contracts-upgradeable` imports.

**Instead:** We implement `ICCIPReceiver` directly, store the router address in upgradeable storage, and provide our own `onlyRouter` modifier.

### 2. Use full Chainlink Client.sol library
**Rejected.** The `Client.sol` library from `chainlink-ccip` contains extensive SVM/SUI constants that cause Yul stack-too-deep compilation errors with `via_ir = true`.

**Instead:** We created `CCIPTypes.sol` — a minimal library containing only the EVM structs, constants, and interfaces we actually use. This compiles cleanly and avoids pulling in unused cross-VM code.

### 3. Queue-based receiver (write to staging, then commit)
**Rejected.** Adds complexity without clear benefit for MVP. The receiver is trusted (allowlisted sender + allowlisted chain) and writes directly to the CredentialRegistry.

### 4. LINK token fee payment
**Rejected for MVP.** Native ETH payment is simpler — no need to manage LINK token balances, approvals, or funding. Can be added in a future version.

## Deployment Procedure

1. Deploy `TLHCCIPReceiver` on Ethereum Sepolia:
   ```bash
   DEPLOY_MODE=receiver CCIP_ROUTER=0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59 \
   CREDENTIAL_REGISTRY=<registry_proxy> forge script DeployCCIP --broadcast
   ```

2. Configure receiver:
   ```
   receiver.configureSourceChain(3478487238524512106, true)
   receiver.configureSender(3478487238524512106, <sender_proxy>, true)
   credentialRegistry.grantVerifier(<receiver_proxy>)
   ```

3. Deploy `TLHCCIPSender` on Arbitrum Sepolia:
   ```bash
   DEPLOY_MODE=sender CCIP_ROUTER=0x2a9C5afb0d0e86603169DdbD7836e478b4624789 \
   CREDENTIAL_REGISTRY=<registry_proxy> forge script DeployCCIP --broadcast
   ```

4. Configure sender:
   ```
   sender.configureDestination(16015286601757825753, <receiver_proxy>, true)
   sender.grantRole(SENDER_ROLE, <authorized_sender>)
   ```

## Consequences

- Cross-chain credential transfer works via CCIP without custom bridge infrastructure
- 39 new tests (17 sender + 18 receiver + 4 integration) validate all paths
- MockCCIPRouter enables full integration testing locally (auto-deliver mode)
- Protocol version tag future-proofs payload format changes
- Storage gap (`uint256[50]`) in both contracts allows safe upgrades
