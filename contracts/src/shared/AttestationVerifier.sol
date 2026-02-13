// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {BaseAttestationVerifier} from "../base/BaseAttestationVerifier.sol";
import {IAttestationVerifier} from "../interfaces/IAttestationVerifier.sol";
import {IDIDRegistry} from "../interfaces/IDIDRegistry.sol";
import {IVCHashAnchors} from "../interfaces/IVCHashAnchors.sol";
import {DIDRegistry} from "./DIDRegistry.sol";

/// @title AttestationVerifier (Shared Anchor)
/// @notice Verifies DON/relayer attestations and triggers Shared Anchor writes:
///         - register/confirm DID in DIDRegistry
///         - anchor VC content hash in VCHashAnchors
/// @dev UUPS upgradeable. Failure paths revert with custom errors (no rejection events).
///      Side-effects (DID registration, hash anchoring) only occur for positive attestations (result == true).
contract AttestationVerifier is BaseAttestationVerifier, UUPSUpgradeable, IAttestationVerifier {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // External dependencies configured via initializer (no hardcoded addresses)
    IDIDRegistry public didRegistry;
    IVCHashAnchors public vcHashAnchors;

    // -------------------------
    // Events (shared-anchor specific)
    // -------------------------
    event DIDRegisteredViaAttestation(bytes32 indexed subjectDID, bytes32 indexed attestationId);
    event VCHashAnchoredViaAttestation(
        bytes32 indexed subjectDID, bytes32 indexed vcType, bytes32 contentHash, bytes32 indexed attestationId
    );

    // -------------------------
    // Custom errors (P1 F-07, F-08)
    // -------------------------
    error ResultMismatch();
    error CredentialExpiredOnSubmission(uint256 expiresAt);

    /// @notice Initialize the verifier (proxy).
    /// @param admin Admin address for roles.
    /// @param didRegistry_ DID Registry contract address.
    /// @param vcHashAnchors_ VC Hash Anchors contract address.
    function initialize(address admin, address didRegistry_, address vcHashAnchors_) external initializer {
        __BaseAttestationVerifier_init(admin);

        _grantRole(UPGRADER_ROLE, admin);

        didRegistry = IDIDRegistry(didRegistry_);
        vcHashAnchors = IVCHashAnchors(vcHashAnchors_);
    }

    /// @notice Submit a signed attestation.
    /// @dev predicateData ABI encoding defined in ADR-002.
    function submitAttestation(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bytes calldata signature
    ) external override {
        _verifyAndStore(attestationId, subjectDID, predicateData, signature);
    }

    /// @notice Read an attestation record by id.
    function verifyAttestation(bytes32 attestationId)
        external
        view
        override
        returns (bool exists, bytes32 subjectDID, bytes32 predicateHash, bool result, uint256 timestamp)
    {
        Attestation memory att = attestations[attestationId];
        if (att.timestamp == 0) {
            return (false, bytes32(0), bytes32(0), false, 0);
        }
        return (true, att.subjectDID, att.predicateHash, att.result, att.timestamp);
    }

    /// @dev Hook: after successful verification, trigger Shared Anchor side-effects.
    ///      Decodes vcType and contentHash from predicateData per ADR-002 layout.
    ///      F-01: Only triggers side-effects when result == true.
    ///      F-07: Validates that byte-level result matches ABI-encoded result.
    ///      F-08: Validates credential is not expired at submission time.
    function _onAttestationVerified(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bool result
    ) internal override {
        // Decode predicateData (ADR-002 canonical layout):
        // predicateData = [0] result byte | [1:] abi.encode(predicateType, result, checkedAt, expiresAt, vcType, contentHash, extra)
        (, bool abiResult,, uint256 expiresAt, bytes32 vcType, bytes32 contentHash,) =
            abi.decode(predicateData[1:], (bytes32, bool, uint256, uint256, bytes32, bytes32, bytes));

        // F-07: Enforce consistency between byte-level result and ABI-encoded result
        if (result != abiResult) revert ResultMismatch();

        // F-01: Negative attestations must NOT trigger credential-confirming side-effects
        if (!result) return;

        // F-08: Enforce expiry — credential must not already be expired at submission time
        if (expiresAt != 0 && expiresAt <= block.timestamp) revert CredentialExpiredOnSubmission(expiresAt);

        // 1) Register DID if not already known
        // F-03: Only swallow DIDAlreadyRegistered; propagate unexpected errors
        try didRegistry.registerDID(subjectDID, address(this)) {
            emit DIDRegisteredViaAttestation(subjectDID, attestationId);
        } catch (bytes memory reason) {
            bytes4 selector = bytes4(reason);
            if (selector != DIDRegistry.DIDAlreadyRegistered.selector) {
                /// @solidity memory-safe-assembly
                assembly {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }

        // 2) Anchor VC content hash
        vcHashAnchors.anchorHash(subjectDID, vcType, contentHash);
        emit VCHashAnchoredViaAttestation(subjectDID, vcType, contentHash, attestationId);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
