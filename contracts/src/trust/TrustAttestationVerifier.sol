// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {BaseAttestationVerifier} from "../base/BaseAttestationVerifier.sol";
import {IAttestationVerifier} from "../interfaces/IAttestationVerifier.sol";
import {ICredentialRegistry} from "../interfaces/ICredentialRegistry.sol";

/// @title TrustAttestationVerifier (Trust Private Chain)
/// @notice Verifies attestations on the trust chain and writes/updates CredentialRegistry on success.
/// @dev UUPS upgradeable. Failure paths revert with custom errors (no rejection events).
contract TrustAttestationVerifier is BaseAttestationVerifier, UUPSUpgradeable, IAttestationVerifier {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    error InvalidCredentialRegistry(address credentialRegistry);

    ICredentialRegistry public credentialRegistry;

    // -------------------------
    // Events (trust-chain specific)
    // -------------------------
    event CredentialWrittenViaAttestation(
        bytes32 indexed subjectDID, bytes32 indexed predicateType, bytes32 indexed attestationId
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the verifier (proxy).
    /// @param admin Admin for BaseAttestationVerifier roles.
    /// @param credentialRegistry_ CredentialRegistry contract address.
    function initialize(address admin, address credentialRegistry_) external initializer {
        if (credentialRegistry_ == address(0)) revert InvalidCredentialRegistry(credentialRegistry_);

        __BaseAttestationVerifier_init(admin);

        _grantRole(UPGRADER_ROLE, admin);

        credentialRegistry = ICredentialRegistry(credentialRegistry_);
    }

    /// @notice Submit a signed attestation.
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

    /// @dev On trust chain, decode predicateData (ADR-002) and write to credential registry
    ///      only when the attestation result is positive (result == true).
    ///      predicateData layout: [0] = result byte (used by base), [1:] = abi.encode(predicateType, result, checkedAt, expiresAt, vcType, contentHash, extra)
    function _onAttestationVerified(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bool result
    ) internal override {
        if (result) {
            // Decode predicateType and expiresAt from predicateData (skip result byte at [0])
            (bytes32 predicateType,,, uint256 expiresAt,,,) =
                abi.decode(predicateData[1:], (bytes32, bool, uint256, uint256, bytes32, bytes32, bytes));

            credentialRegistry.writeCredential(subjectDID, predicateType, result, expiresAt, attestationId);
            emit CredentialWrittenViaAttestation(subjectDID, predicateType, attestationId);
        }
    }

    /// @notice Update the credential registry address (admin only).
    function setCredentialRegistry(address credentialRegistry_) external onlyRole(ADMIN_ROLE) {
        if (credentialRegistry_ == address(0)) revert InvalidCredentialRegistry(credentialRegistry_);
        credentialRegistry = ICredentialRegistry(credentialRegistry_);
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
