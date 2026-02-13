// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title CredentialRegistry (Trust Private Chain)
/// @notice Stores trust-local credential state for clinician DIDs.
/// @dev UUPS upgradeable; only success-path events are emitted.
contract CredentialRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    enum CredentialStatus {
        Active,
        Expired,
        Revoked
    }

    struct Credential {
        bytes32 subjectDID;
        bytes32 predicateType;
        bool valid;
        uint256 checkedAt;
        uint256 expiresAt;
        bytes32 attestationId;
        CredentialStatus status;
    }

    // subjectDID => predicateType => credential
    mapping(bytes32 => mapping(bytes32 => Credential)) private _credentials;

    // subjectDID => list of predicateTypes (for enumeration)
    mapping(bytes32 => bytes32[]) private _predicateTypesByDID;
    mapping(bytes32 => mapping(bytes32 => bool)) private _predicateTypeSeen;

    error UnauthorizedCredentialWriter(address caller);
    error CredentialNotFound(bytes32 subjectDID, bytes32 predicateType);
    error CredentialAlreadyRevoked(bytes32 subjectDID, bytes32 predicateType);

    event CredentialWritten(
        bytes32 indexed subjectDID, bytes32 indexed predicateType, bool valid, bytes32 attestationId, uint256 timestamp
    );

    event CredentialRevoked(bytes32 indexed subjectDID, bytes32 indexed predicateType, uint256 timestamp);

    function initialize(address admin) external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /// @notice Write or update a credential (verifier only).
    function writeCredential(
        bytes32 subjectDID,
        bytes32 predicateType,
        bool valid,
        uint256 expiresAt,
        bytes32 attestationId
    ) external {
        if (!hasRole(VERIFIER_ROLE, msg.sender)) revert UnauthorizedCredentialWriter(msg.sender);

        Credential storage c = _credentials[subjectDID][predicateType];
        c.subjectDID = subjectDID;
        c.predicateType = predicateType;
        c.valid = valid;
        c.checkedAt = block.timestamp;
        c.expiresAt = expiresAt;
        c.attestationId = attestationId;

        if (c.status != CredentialStatus.Revoked) {
            c.status = _computeStatus(valid, expiresAt);
        }

        if (!_predicateTypeSeen[subjectDID][predicateType]) {
            _predicateTypeSeen[subjectDID][predicateType] = true;
            _predicateTypesByDID[subjectDID].push(predicateType);
        }

        emit CredentialWritten(subjectDID, predicateType, valid, attestationId, block.timestamp);
    }

    function getCredential(bytes32 subjectDID, bytes32 predicateType) external view returns (Credential memory) {
        Credential memory c = _credentials[subjectDID][predicateType];
        if (c.subjectDID == bytes32(0)) revert CredentialNotFound(subjectDID, predicateType);
        return _withLiveStatus(c);
    }

    function getCredentialsByDID(bytes32 subjectDID) external view returns (Credential[] memory) {
        bytes32[] memory types_ = _predicateTypesByDID[subjectDID];
        Credential[] memory out = new Credential[](types_.length);
        for (uint256 i = 0; i < types_.length; i++) {
            Credential memory c = _credentials[subjectDID][types_[i]];
            out[i] = _withLiveStatus(c);
        }
        return out;
    }

    function revokeCredential(bytes32 subjectDID, bytes32 predicateType) external {
        if (!(hasRole(VERIFIER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender))) {
            revert UnauthorizedCredentialWriter(msg.sender);
        }

        Credential storage c = _credentials[subjectDID][predicateType];
        if (c.subjectDID == bytes32(0)) revert CredentialNotFound(subjectDID, predicateType);
        if (c.status == CredentialStatus.Revoked) revert CredentialAlreadyRevoked(subjectDID, predicateType);

        c.status = CredentialStatus.Revoked;
        c.valid = false;

        emit CredentialRevoked(subjectDID, predicateType, block.timestamp);
    }

    function isCredentialValid(bytes32 subjectDID, bytes32 predicateType) external view returns (bool) {
        Credential memory c = _credentials[subjectDID][predicateType];
        if (c.subjectDID == bytes32(0)) return false;
        if (c.status == CredentialStatus.Revoked) return false;
        if (c.expiresAt != 0 && block.timestamp > c.expiresAt) return false;
        return c.valid;
    }

    function grantVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        _grantRole(VERIFIER_ROLE, verifier);
    }

    function _computeStatus(bool valid, uint256 expiresAt) internal view returns (CredentialStatus) {
        if (!valid) return CredentialStatus.Expired;
        if (expiresAt != 0 && block.timestamp > expiresAt) return CredentialStatus.Expired;
        return CredentialStatus.Active;
    }

    function _withLiveStatus(Credential memory c) internal view returns (Credential memory) {
        if (c.subjectDID == bytes32(0)) return c;
        if (c.status == CredentialStatus.Revoked) return c;
        if (c.expiresAt != 0 && block.timestamp > c.expiresAt) {
            c.status = CredentialStatus.Expired;
            c.valid = false;
        }
        return c;
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
