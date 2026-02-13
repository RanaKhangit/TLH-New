// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAttestationVerifier
/// @notice Shared interface for both Shared Anchor and Trust Chain attestation verifiers.
interface IAttestationVerifier {
    /// @notice Submit an attestation for verification and storage (reverts on invalid input).
    function submitAttestation(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bytes calldata signature
    ) external;

    /// @notice Verify (query) an attestation by ID.
    /// @return exists Whether attestation exists.
    /// @return subjectDID Subject DID.
    /// @return predicateHash Hash of predicateData stored.
    /// @return result Decoded predicate result flag (first byte convention).
    /// @return timestamp When stored.
    function verifyAttestation(bytes32 attestationId)
        external
        view
        returns (bool exists, bytes32 subjectDID, bytes32 predicateHash, bool result, uint256 timestamp);
}
