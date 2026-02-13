// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICredentialRegistry
/// @notice Minimal interface for Trust chain credential registry.
interface ICredentialRegistry {
    function writeCredential(
        bytes32 subjectDID,
        bytes32 predicateType,
        bool valid,
        uint256 expiresAt,
        bytes32 attestationId
    ) external;
}
