// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IVCHashAnchors
/// @notice Minimal interface for VC hash anchors used by shared verifier.
/// @dev ADR-003 §E specifies a 4-param signature (including attestationId); this interface
///      uses a 3-param signature as an intentional M1 simplification — attestationId linkage
///      is tracked via events rather than storage.
interface IVCHashAnchors {
    /// @notice Anchor a verifiable credential hash on-chain.
    /// @param subjectDID DID of the credential subject.
    /// @param vcType Credential type identifier (e.g., keccak256("GMC_LICENSE")).
    /// @param contentHash Privacy-preserving hash of the VC content.
    function anchorHash(bytes32 subjectDID, bytes32 vcType, bytes32 contentHash) external;
}
