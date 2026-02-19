// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ICredentialRegistry
/// @notice Minimal interface for Trust chain credential registry.
interface ICredentialRegistry {
    /// @notice Write or update a credential record for a subject.
    /// @param subjectDID DID of the credential subject.
    /// @param predicateType Predicate type identifier (e.g., keccak256("GMC_REGISTERED")).
    /// @param valid Whether the credential is currently valid.
    /// @param expiresAt UNIX timestamp when the credential expires (0 = non-expiring).
    /// @param attestationId Attestation ID that sourced this credential write.
    function writeCredential(
        bytes32 subjectDID,
        bytes32 predicateType,
        bool valid,
        uint256 expiresAt,
        bytes32 attestationId
    ) external;

    /// @notice Check whether a credential is currently valid.
    function isCredentialValid(bytes32 subjectDID, bytes32 predicateType) external view returns (bool);

    /// @notice Get credential validity and expiry data for cross-chain messaging.
    function getCredentialInfo(bytes32 subjectDID, bytes32 predicateType)
        external view returns (bool valid, uint256 expiresAt);
}
