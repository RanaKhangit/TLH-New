// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IDIDRegistry
/// @notice Minimal interface for DID Registry used by verifiers.
interface IDIDRegistry {
    function registerDID(bytes32 did, address controller) external;

    function resolveDID(bytes32 did)
        external
        view
        returns (address controller, bool active, uint256 registeredAt, uint256 updatedAt);
}
