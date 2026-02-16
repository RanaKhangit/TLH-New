// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {CCIPTypes, ICCIPReceiver} from "./CCIPTypes.sol";
import {ICredentialRegistry} from "../interfaces/ICredentialRegistry.sol";
import {ITLHCCIPReceiver} from "../interfaces/ITLHCCIPReceiver.sol";

/// @title TLHCCIPReceiver
/// @notice Receives cross-chain CCIP messages from TLHCCIPSender and writes
///         credentials into the anchor-chain CredentialRegistry.
/// @dev UUPS upgradeable. Implements ICCIPReceiver directly (instead of
///      inheriting CCIPReceiver) to avoid immutable/proxy conflicts.
contract TLHCCIPReceiver is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ICCIPReceiver,
    ITLHCCIPReceiver
{
    // ── Roles ────────────────────────────────────────────────────────────
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ── Protocol constant ────────────────────────────────────────────────
    bytes32 public constant PROTOCOL_VERSION = keccak256("CCIP_TLH_V1");

    // ── Storage ──────────────────────────────────────────────────────────
    address public ccipRouter;
    ICredentialRegistry public credentialRegistry;

    /// @notice Allowlisted source chains.
    mapping(uint64 => bool) public allowedSourceChains;

    /// @notice Allowlisted senders per source chain.
    mapping(uint64 => mapping(address => bool)) public allowedSenders;

    /// @notice Last processed nonce per source chain (for replay protection).
    mapping(uint64 => uint256) private _lastNonce;

    // ── Errors ───────────────────────────────────────────────────────────
    error SourceChainNotAllowed(uint64 sourceChainSelector);
    error SenderNotAllowed(uint64 sourceChainSelector, address sender);
    error InvalidProtocolVersion(bytes32 expected, bytes32 actual);
    error InvalidNonce(uint64 sourceChainSelector, uint256 expected, uint256 actual);
    error InvalidRouter(address router);
    error InvalidAdmin(address admin);
    error InvalidRegistry(address registry);

    // ── Events ───────────────────────────────────────────────────────────
    event CredentialReceivedViaCCIP(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address sender,
        bytes32 indexed subjectDID,
        bytes32 predicateType,
        uint256 nonce
    );

    event SourceChainConfigured(uint64 indexed sourceChainSelector, bool enabled);
    event SenderConfigured(uint64 indexed sourceChainSelector, address indexed sender, bool enabled);

    // ── Constructor (UUPS) ───────────────────────────────────────────────
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ── Initializer ──────────────────────────────────────────────────────
    /// @notice Initialize the receiver proxy.
    /// @param admin Address granted admin and upgrader roles.
    /// @param router_ CCIP router address on the anchor chain.
    /// @param registry_ Anchor-chain CredentialRegistry address.
    function initialize(address admin, address router_, address registry_) external initializer {
        if (admin == address(0)) revert InvalidAdmin(admin);
        if (router_ == address(0)) revert InvalidRouter(router_);
        if (registry_ == address(0)) revert InvalidRegistry(registry_);

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        ccipRouter = router_;
        credentialRegistry = ICredentialRegistry(registry_);
    }

    // ── CCIP entry point ─────────────────────────────────────────────────
    /// @inheritdoc ICCIPReceiver
    function ccipReceive(CCIPTypes.Any2EVMMessage calldata message) external override onlyRouter {
        _ccipReceive(message);
    }

    // ── ERC-165 ──────────────────────────────────────────────────────────
    /// @notice Indicates support for ICCIPReceiver and ERC-165.
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(ICCIPReceiver).interfaceId
            || interfaceId == 0x01ffc9a7; // IERC165
    }

    // ── Views ────────────────────────────────────────────────────────────
    /// @inheritdoc ITLHCCIPReceiver
    function isChainAllowlisted(uint64 sourceChainSelector) external view returns (bool) {
        return allowedSourceChains[sourceChainSelector];
    }

    /// @inheritdoc ITLHCCIPReceiver
    function isSenderAllowlisted(uint64 sourceChainSelector, address sender) external view returns (bool) {
        return allowedSenders[sourceChainSelector][sender];
    }

    /// @inheritdoc ITLHCCIPReceiver
    function getLastNonce(uint64 sourceChainSelector) external view returns (uint256) {
        return _lastNonce[sourceChainSelector];
    }

    /// @notice Return the CCIP router address.
    function getRouter() public view returns (address) {
        return ccipRouter;
    }

    // ── Admin: configure source chain ────────────────────────────────────
    /// @notice Enable or disable a source chain for receiving messages.
    /// @param sourceChainSelector CCIP chain selector.
    /// @param enabled Whether this source chain is allowed.
    function configureSourceChain(uint64 sourceChainSelector, bool enabled) external onlyRole(ADMIN_ROLE) {
        allowedSourceChains[sourceChainSelector] = enabled;
        emit SourceChainConfigured(sourceChainSelector, enabled);
    }

    /// @notice Enable or disable a specific sender on a source chain.
    /// @param sourceChainSelector CCIP chain selector.
    /// @param sender Address of the sender contract.
    /// @param enabled Whether this sender is allowed.
    function configureSender(
        uint64 sourceChainSelector,
        address sender,
        bool enabled
    ) external onlyRole(ADMIN_ROLE) {
        allowedSenders[sourceChainSelector][sender] = enabled;
        emit SenderConfigured(sourceChainSelector, sender, enabled);
    }

    // ── Internal: process CCIP message ───────────────────────────────────
    function _ccipReceive(CCIPTypes.Any2EVMMessage calldata message) internal {
        uint64 sourceChain = message.sourceChainSelector;
        address sender = abi.decode(message.sender, (address));

        // Allowlist checks
        if (!allowedSourceChains[sourceChain]) revert SourceChainNotAllowed(sourceChain);
        if (!allowedSenders[sourceChain][sender]) revert SenderNotAllowed(sourceChain, sender);

        // Decode payload
        (
            bytes32 protocolVersion,
            uint256 nonce,
            bytes32 subjectDID,
            bytes32 predicateType,
            bool valid,
            uint256 expiresAt,
            bytes32 attestationId
        ) = abi.decode(message.data, (bytes32, uint256, bytes32, bytes32, bool, uint256, bytes32));

        // Protocol version check
        if (protocolVersion != PROTOCOL_VERSION) {
            revert InvalidProtocolVersion(PROTOCOL_VERSION, protocolVersion);
        }

        // Sequential nonce check
        uint256 expectedNonce = _lastNonce[sourceChain];
        if (nonce != expectedNonce) revert InvalidNonce(sourceChain, expectedNonce, nonce);
        _lastNonce[sourceChain] = nonce + 1;

        // Write credential to the anchor-chain registry
        credentialRegistry.writeCredential(subjectDID, predicateType, valid, expiresAt, attestationId);

        emit CredentialReceivedViaCCIP(
            message.messageId, sourceChain, sender, subjectDID, predicateType, nonce
        );
    }

    // ── Modifier: only CCIP router ───────────────────────────────────────
    modifier onlyRouter() {
        if (msg.sender != ccipRouter) revert InvalidRouter(msg.sender);
        _;
    }

    // ── UUPS authorization ───────────────────────────────────────────────
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ── Storage gap ──────────────────────────────────────────────────────
    uint256[50] private __gap;
}
