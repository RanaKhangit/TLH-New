// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IVCHashAnchors
/// @notice Minimal interface for VC hash anchors used by shared verifier.
interface IVCHashAnchors {
    function anchorHash(bytes32 subjectDID, bytes32 vcType, bytes32 contentHash) external;
}
