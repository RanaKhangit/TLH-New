// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITLHCCIPSender
/// @notice Interface for the cross-chain credential sender (Trust → Anchor chain).
interface ITLHCCIPSender {
    /// @notice Send a credential cross-chain via CCIP.
    /// @param destChainSelector CCIP destination chain selector.
    /// @param subjectDID DID of the credential subject.
    /// @param predicateType Predicate type identifier.
    /// @return messageId The CCIP message ID.
    function sendCredential(
        uint64 destChainSelector,
        bytes32 subjectDID,
        bytes32 predicateType
    ) external payable returns (bytes32 messageId);

    /// @notice Estimate the CCIP fee for sending a credential.
    /// @param destChainSelector CCIP destination chain selector.
    /// @param subjectDID DID of the credential subject.
    /// @param predicateType Predicate type identifier.
    /// @return fee The estimated fee in native currency.
    function estimateFee(
        uint64 destChainSelector,
        bytes32 subjectDID,
        bytes32 predicateType
    ) external view returns (uint256 fee);

    /// @notice Get the next nonce for a destination chain.
    /// @param destChainSelector CCIP destination chain selector.
    /// @return nonce The next nonce value.
    function getNextNonce(uint64 destChainSelector) external view returns (uint256 nonce);
}
