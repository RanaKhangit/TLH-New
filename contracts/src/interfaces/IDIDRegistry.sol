// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IDIDRegistry
/// @notice Minimal interface for DID Registry used by verifiers.
interface IDIDRegistry {
    /// @notice Register a new DID with an associated controller.
    /// @param did Unique DID identifier (bytes32).
    /// @param controller Address that controls the DID.
    function registerDID(bytes32 did, address controller) external;

    /// @notice Resolve a DID to its on-chain record.
    /// @param did DID identifier to look up.
    /// @return controller Address controlling the DID.
    /// @return active Whether the DID is currently active.
    /// @return registeredAt Timestamp when the DID was registered.
    /// @return updatedAt Timestamp of the last update.
    function resolveDID(bytes32 did)
        external
        view
        returns (address controller, bool active, uint256 registeredAt, uint256 updatedAt);
}
