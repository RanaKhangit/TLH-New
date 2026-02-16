// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ITLHCCIPReceiver
/// @notice Interface for the cross-chain credential receiver (Anchor chain).
interface ITLHCCIPReceiver {
    /// @notice Check if a source chain is allowlisted.
    /// @param sourceChainSelector CCIP source chain selector.
    /// @return True if the chain is allowed.
    function isChainAllowlisted(uint64 sourceChainSelector) external view returns (bool);

    /// @notice Check if a sender on a source chain is allowlisted.
    /// @param sourceChainSelector CCIP source chain selector.
    /// @param sender Address of the sender contract on the source chain.
    /// @return True if the sender is allowed.
    function isSenderAllowlisted(uint64 sourceChainSelector, address sender) external view returns (bool);

    /// @notice Get the last processed nonce for a source chain.
    /// @param sourceChainSelector CCIP source chain selector.
    /// @return nonce The last processed nonce.
    function getLastNonce(uint64 sourceChainSelector) external view returns (uint256 nonce);
}
