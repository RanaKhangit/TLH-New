// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {BaseAttestationVerifier} from "../base/BaseAttestationVerifier.sol";
import {IAttestationVerifier} from "../interfaces/IAttestationVerifier.sol";
import {IDIDRegistry} from "../interfaces/IDIDRegistry.sol";
import {IVCHashAnchors} from "../interfaces/IVCHashAnchors.sol";

/// @title AttestationVerifier (Shared Anchor)
/// @notice Verifies DON/relayer attestations and triggers Shared Anchor writes:
///         - register/confirm DID in DIDRegistry
///         - anchor VC content hash in VCHashAnchors
/// @dev UUPS upgradeable. Failure paths revert with custom errors (no rejection events).
contract AttestationVerifier is BaseAttestationVerifier, UUPSUpgradeable, IAttestationVerifier {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // External dependencies configured via initializer (no hardcoded addresses)
    IDIDRegistry public didRegistry;
    IVCHashAnchors public vcHashAnchors;

    // -------------------------
    // Events (shared-anchor specific, success-path only)
    // -------------------------
    event DIDRegisteredViaAttestation(bytes32 indexed subjectDID, bytes32 indexed attestationId);
    event VCHashAnchoredViaAttestation(
        bytes32 indexed subjectDID, bytes32 indexed vcType, bytes32 contentHash, bytes32 indexed attestationId
    );

    /// @dev Emitted after the full shared-anchor flow completes (verify + DID + VC hash).
    ///      Provides a single event subscribers can watch for credential status changes.
    event CredentialStatusUpdated(
        bytes32 indexed subjectDID,
        bytes32 indexed vcType,
        bool result,
        bytes32 indexed attestationId,
        uint256 timestamp
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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
    ///      Only positive attestations (result == true) trigger DID registration,
    ///      hash anchoring, and credential events (F-01).
    ///      Decodes vcType and contentHash from predicateData per ADR-002 layout.
    function _onAttestationVerified(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bool result
    ) internal override {
        // F-01: negative attestations are stored (base) but do not trigger side-effects
        if (!result) return;

        // Decode vcType and contentHash from predicateData (ADR-002 canonical layout):
        // predicateData[0] = result byte (used by base), [1:] = abi.encode(predicateType, ...)
        (,,,, bytes32 vcType, bytes32 contentHash,) =
            abi.decode(predicateData[1:], (bytes32, bool, uint256, uint256, bytes32, bytes32, bytes));

        // 1) Register DID if not already known
        // F-03: only swallow DIDAlreadyRegistered; propagate unexpected errors
        try didRegistry.registerDID(subjectDID, address(this)) {
            emit DIDRegisteredViaAttestation(subjectDID, attestationId);
        } catch (bytes memory reason) {
            if (reason.length < 4 || bytes4(reason) != IDIDRegistry.DIDAlreadyRegistered.selector) {
                assembly {
                    revert(add(reason, 32), mload(reason))
                }
            }
        }

        // 2) Anchor VC content hash
        vcHashAnchors.anchorHash(subjectDID, vcType, contentHash);
        emit VCHashAnchoredViaAttestation(subjectDID, vcType, contentHash, attestationId);

        // 3) Emit composite status event for subscribers
        emit CredentialStatusUpdated(subjectDID, vcType, result, attestationId, block.timestamp);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
