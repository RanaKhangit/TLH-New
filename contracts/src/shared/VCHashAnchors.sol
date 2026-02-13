// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title VCHashAnchors
/// @notice Stores VC content hashes (privacy-preserving) keyed by (subjectDID, vcType).
/// @dev Hash-only storage; no underlying data. Success-path events only; invalid operations revert with custom errors.
///      UUPS upgradeable; upgrade auth controlled via UPGRADER_ROLE.
contract VCHashAnchors is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ANCHOR_WRITER_ROLE = keccak256("ANCHOR_WRITER_ROLE");

    error UnauthorizedAnchorWriter(address caller);
    error AnchorNotFound(bytes32 subjectDID, bytes32 vcType);
    error AnchorAlreadyRevoked(bytes32 subjectDID, bytes32 vcType);
    error AnchorIsRevoked(bytes32 subjectDID, bytes32 vcType);

    event HashAnchored(bytes32 indexed subjectDID, bytes32 indexed vcType, bytes32 contentHash, uint256 timestamp);
    event AnchorRevoked(bytes32 indexed subjectDID, bytes32 indexed vcType, uint256 timestamp);

    struct AnchorRecord {
        bytes32 contentHash;
        uint256 anchoredAt;
        bool revoked;
    }

    // Current (latest) anchor record
    mapping(bytes32 => mapping(bytes32 => AnchorRecord)) private anchors;

    // Append-only history of hashes (latest at end)
    mapping(bytes32 => mapping(bytes32 => bytes32[])) private anchorHistory;

    /// @notice Initialize the contract (proxy).
    /// @param admin Admin address that receives roles.
    function initialize(address admin) external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /// @notice Store a new VC content hash anchor for a subjectDID and vcType.
    /// @dev Only ANCHOR_WRITER_ROLE can write (typically the Shared Attestation Verifier).
    function anchorHash(bytes32 subjectDID, bytes32 vcType, bytes32 contentHash) external {
        if (!hasRole(ANCHOR_WRITER_ROLE, msg.sender)) revert UnauthorizedAnchorWriter(msg.sender);

        AnchorRecord storage rec = anchors[subjectDID][vcType];

        // F-14: Durable revocation — once revoked, anchorHash must not silently un-revoke
        if (rec.revoked) revert AnchorIsRevoked(subjectDID, vcType);

        rec.contentHash = contentHash;
        rec.anchoredAt = block.timestamp;

        anchorHistory[subjectDID][vcType].push(contentHash);

        emit HashAnchored(subjectDID, vcType, contentHash, block.timestamp);
    }

    /// @notice Get the latest anchor for (subjectDID, vcType).
    function getAnchor(bytes32 subjectDID, bytes32 vcType)
        external
        view
        returns (bytes32 contentHash, uint256 anchoredAt, bool revoked)
    {
        AnchorRecord memory rec = anchors[subjectDID][vcType];
        if (rec.anchoredAt == 0) revert AnchorNotFound(subjectDID, vcType);
        return (rec.contentHash, rec.anchoredAt, rec.revoked);
    }

    /// @notice Get full hash history for (subjectDID, vcType).
    function getAnchorHistory(bytes32 subjectDID, bytes32 vcType) external view returns (bytes32[] memory) {
        return anchorHistory[subjectDID][vcType];
    }

    /// @notice Revoke the latest anchor for (subjectDID, vcType).
    /// @dev Only ADMIN_ROLE can revoke (emergency/admin action). Revocation is irreversible; new attestation must re-anchor.
    function revokeAnchor(bytes32 subjectDID, bytes32 vcType) external onlyRole(ADMIN_ROLE) {
        AnchorRecord storage rec = anchors[subjectDID][vcType];
        if (rec.anchoredAt == 0) revert AnchorNotFound(subjectDID, vcType);
        if (rec.revoked) revert AnchorAlreadyRevoked(subjectDID, vcType);

        rec.revoked = true;
        emit AnchorRevoked(subjectDID, vcType, block.timestamp);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
