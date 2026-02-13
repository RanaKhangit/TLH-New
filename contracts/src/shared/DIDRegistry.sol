// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

/// @title DIDRegistry
/// @notice Shared Anchor Chain DID Registry for clinician subjects.
/// @dev UUPS upgradeable. No constructors. Success-path events only; failure paths revert with custom errors.
contract DIDRegistry is Initializable, UUPSUpgradeable, AccessControlUpgradeable {
    /// @notice Role allowed to register new DIDs.
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    /// @notice Role allowed to authorize upgrades (must be a multisig in production).
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice DID record structure.
    struct DIDRecord {
        address controller;
        bool active;
        uint256 registeredAt;
        uint256 updatedAt;
    }

    /// @dev did => record
    mapping(bytes32 => DIDRecord) private _records;

    // -------------------------
    // Custom errors
    // -------------------------
    error DIDAlreadyRegistered(bytes32 did);
    error DIDNotFound(bytes32 did);
    error NotDIDController(bytes32 did, address caller);
    error DIDAlreadyDeactivated(bytes32 did);

    // -------------------------
    // Events (success-path only)
    // -------------------------
    event DIDRegistered(bytes32 indexed did, address indexed controller, uint256 timestamp);
    event DIDDeactivated(bytes32 indexed did, uint256 timestamp);
    event DIDControllerUpdated(bytes32 indexed did, address indexed oldController, address indexed newController);

    /// @notice Initializes the registry.
    /// @param admin Address granted DEFAULT_ADMIN_ROLE, REGISTRAR_ROLE, and UPGRADER_ROLE.
    function initialize(address admin) external initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    /// @notice Register a new DID.
    /// @dev Requires REGISTRAR_ROLE. Reverts if DID exists (active or deactivated).
    /// @param did DID identifier (bytes32).
    /// @param controller Controller address for this DID.
    function registerDID(bytes32 did, address controller) external onlyRole(REGISTRAR_ROLE) {
        DIDRecord storage r = _records[did];
        if (r.registeredAt != 0) revert DIDAlreadyRegistered(did);

        r.controller = controller;
        r.active = true;
        r.registeredAt = block.timestamp;
        r.updatedAt = block.timestamp;

        emit DIDRegistered(did, controller, block.timestamp);
    }

    /// @notice Resolve a DID.
    /// @dev Reverts if DID is not found.
    /// @param did DID identifier (bytes32).
    /// @return controller Controller address.
    /// @return active Active status.
    /// @return registeredAt Registration timestamp.
    /// @return updatedAt Last update timestamp.
    function resolveDID(bytes32 did)
        external
        view
        returns (address controller, bool active, uint256 registeredAt, uint256 updatedAt)
    {
        DIDRecord storage r = _records[did];
        if (r.registeredAt == 0) revert DIDNotFound(did);
        return (r.controller, r.active, r.registeredAt, r.updatedAt);
    }

    /// @notice Deactivate an existing DID (does not delete).
    /// @dev Controller-only. Reverts if not found, not controller, or already deactivated.
    /// @param did DID identifier (bytes32).
    function deactivateDID(bytes32 did) external {
        DIDRecord storage r = _records[did];
        if (r.registeredAt == 0) revert DIDNotFound(did);
        if (msg.sender != r.controller) revert NotDIDController(did, msg.sender);
        if (!r.active) revert DIDAlreadyDeactivated(did);

        r.active = false;
        r.updatedAt = block.timestamp;

        emit DIDDeactivated(did, block.timestamp);
    }

    /// @notice Update the controller for an existing DID.
    /// @dev Controller-only. Reverts if not found or not controller.
    /// @param did DID identifier (bytes32).
    /// @param newController New controller address.
    function updateController(bytes32 did, address newController) external {
        DIDRecord storage r = _records[did];
        if (r.registeredAt == 0) revert DIDNotFound(did);
        if (msg.sender != r.controller) revert NotDIDController(did, msg.sender);

        address old = r.controller;
        r.controller = newController;
        r.updatedAt = block.timestamp;

        emit DIDControllerUpdated(did, old, newController);
    }

    /// @dev UUPS upgrade authorization.
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
