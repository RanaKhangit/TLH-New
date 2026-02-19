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
    error InvalidAdmin(address admin);
    error InvalidVerifier(address verifier);

    event CredentialWritten(
        bytes32 indexed subjectDID, bytes32 indexed predicateType, bool valid, bytes32 attestationId, uint256 timestamp
    );

    event CredentialRevoked(bytes32 indexed subjectDID, bytes32 indexed predicateType, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the registry (proxy).
    /// @param admin Address granted DEFAULT_ADMIN_ROLE, ADMIN_ROLE, and UPGRADER_ROLE.
    function initialize(address admin) external initializer {
        if (admin == address(0)) revert InvalidAdmin(admin);

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /// @notice Write or update a credential record for a subject.
    /// @dev Reverts if the credential has been revoked. Status set to Active at write-time.
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
    ) external {
        if (!hasRole(VERIFIER_ROLE, msg.sender)) revert UnauthorizedCredentialWriter(msg.sender);

        Credential storage c = _credentials[subjectDID][predicateType];

        // H-7: Prevent overwriting a revoked credential
        if (c.status == CredentialStatus.Revoked) revert CredentialAlreadyRevoked(subjectDID, predicateType);

        c.subjectDID = subjectDID;
        c.predicateType = predicateType;
        c.valid = valid;
        c.checkedAt = block.timestamp;
        c.expiresAt = expiresAt;
        c.attestationId = attestationId;
        c.status = CredentialStatus.Active;

        if (!_predicateTypeSeen[subjectDID][predicateType]) {
            _predicateTypeSeen[subjectDID][predicateType] = true;
            _predicateTypesByDID[subjectDID].push(predicateType);
        }

        emit CredentialWritten(subjectDID, predicateType, valid, attestationId, block.timestamp);
    }

    /// @notice Retrieve a credential record for a subject + predicate type.
    /// @dev Reverts if no credential exists. Returns live status (expiry evaluated at read-time).
    /// @param subjectDID DID of the credential subject.
    /// @param predicateType Predicate type identifier.
    /// @return Credential record with live status.
    function getCredential(bytes32 subjectDID, bytes32 predicateType) external view returns (Credential memory) {
        Credential memory c = _credentials[subjectDID][predicateType];
        if (c.subjectDID == bytes32(0)) revert CredentialNotFound(subjectDID, predicateType);
        return _withLiveStatus(c);
    }

    /// @notice Retrieve all credential records for a given DID.
    /// @param subjectDID DID of the credential subject.
    /// @return Array of Credential records with live status.
    function getCredentialsByDID(bytes32 subjectDID) external view returns (Credential[] memory) {
        bytes32[] memory types_ = _predicateTypesByDID[subjectDID];
        Credential[] memory out = new Credential[](types_.length);
        for (uint256 i = 0; i < types_.length; i++) {
            Credential memory c = _credentials[subjectDID][types_[i]];
            out[i] = _withLiveStatus(c);
        }
        return out;
    }

    /// @notice Revoke a credential (irreversible). Restricted to VERIFIER_ROLE or ADMIN_ROLE.
    /// @param subjectDID DID of the credential subject.
    /// @param predicateType Predicate type identifier.
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

    /// @notice Check whether a credential is currently valid (expiry + revocation aware).
    /// @param subjectDID DID of the credential subject.
    /// @param predicateType Predicate type identifier.
    /// @return True if the credential exists, is not revoked, not expired, and was written as valid.
    function isCredentialValid(bytes32 subjectDID, bytes32 predicateType) external view returns (bool) {
        Credential memory c = _credentials[subjectDID][predicateType];
        if (c.subjectDID == bytes32(0)) return false;
        if (c.status == CredentialStatus.Revoked) return false;
        if (c.expiresAt != 0 && block.timestamp > c.expiresAt) return false;
        return c.valid;
    }

    /// @notice Grant VERIFIER_ROLE to an address (admin only).
    /// @param verifier Address to grant the verifier role to.
    function grantVerifier(address verifier) external onlyRole(ADMIN_ROLE) {
        if (verifier == address(0)) revert InvalidVerifier(verifier);
        _grantRole(VERIFIER_ROLE, verifier);
    }

    /// @notice Get credential validity and expiry (for cross-chain messaging).
    function getCredentialInfo(bytes32 subjectDID, bytes32 predicateType)
        external view returns (bool valid, uint256 expiresAt)
    {
        Credential memory c = _credentials[subjectDID][predicateType];
        if (c.subjectDID == bytes32(0)) return (false, 0);
        Credential memory live = _withLiveStatus(c);
        return (live.valid, live.expiresAt);
    }

    /// @notice Paginated credential retrieval to avoid unbounded gas.
    /// @param subjectDID DID of the credential subject.
    /// @param offset Start index in the predicate types array.
    /// @param limit Maximum number of records to return.
    function getCredentialsByDIDPaginated(bytes32 subjectDID, uint256 offset, uint256 limit)
        external view returns (Credential[] memory)
    {
        bytes32[] memory types_ = _predicateTypesByDID[subjectDID];
        if (offset >= types_.length) return new Credential[](0);
        uint256 end = offset + limit;
        if (end > types_.length) end = types_.length;
        uint256 count = end - offset;
        Credential[] memory out = new Credential[](count);
        for (uint256 i = 0; i < count; i++) {
            out[i] = _withLiveStatus(_credentials[subjectDID][types_[offset + i]]);
        }
        return out;
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
