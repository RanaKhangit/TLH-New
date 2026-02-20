// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {CCIPTypes, ICCIPRouter} from "./CCIPTypes.sol";
import {ICredentialRegistry} from "../interfaces/ICredentialRegistry.sol";
import {ITLHCCIPSender} from "../interfaces/ITLHCCIPSender.sol";

/// @title TLHCCIPSender
/// @notice Reads credentials from a local CredentialRegistry and sends them
///         cross-chain via Chainlink CCIP to the anchor chain.
/// @dev UUPS upgradeable. Pays CCIP fees in native ETH.
contract TLHCCIPSender is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuard, ITLHCCIPSender {
    // ── Roles ────────────────────────────────────────────────────────────
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant SENDER_ROLE = keccak256("SENDER_ROLE");

    // ── Protocol constant ────────────────────────────────────────────────
    bytes32 public constant PROTOCOL_VERSION = keccak256("CCIP_TLH_V1");

    // ── CCIP gas limit for receiver callback ─────────────────────────────
    uint256 public constant CCIP_GAS_LIMIT = 300_000;

    // ── Storage ──────────────────────────────────────────────────────────
    ICCIPRouter public ccipRouter;
    ICredentialRegistry public credentialRegistry;

    /// @notice Per-destination monotonic nonce for replay protection.
    mapping(uint64 => uint256) private _nonces;

    /// @notice Per-destination allowed receiver contract address.
    mapping(uint64 => address) public allowedReceivers;

    /// @notice Per-destination chain enabled flag.
    mapping(uint64 => bool) public allowedDestinations;

    /// @notice M-3 fix: Track unrefunded balances for users whose refunds failed.
    mapping(address => uint256) public unclaimedRefunds;

    // ── Errors ───────────────────────────────────────────────────────────
    error DestinationNotAllowed(uint64 destChainSelector);
    error ReceiverNotSet(uint64 destChainSelector);
    error InsufficientFee(uint256 required, uint256 provided);
    error InvalidAdmin(address admin);
    error InvalidRouter(address router);
    error InvalidRegistry(address registry);
    error CredentialNotValid(bytes32 subjectDID, bytes32 predicateType);

    // ── Events ───────────────────────────────────────────────────────────
    event CredentialSent(
        bytes32 indexed messageId,
        uint64 indexed destChainSelector,
        bytes32 indexed subjectDID,
        bytes32 predicateType,
        uint256 nonce,
        uint256 fee
    );

    event DestinationConfigured(uint64 indexed destChainSelector, address receiver, bool enabled);

    /// @notice M-3 fix: Emitted when refund fails (instead of reverting after CCIP send)
    event RefundFailed(address indexed recipient, uint256 amount);

    // ── Constructor (UUPS) ───────────────────────────────────────────────
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ── Initializer ──────────────────────────────────────────────────────
    /// @notice Initialize the sender proxy.
    /// @param admin Address granted admin, upgrader, and sender roles.
    /// @param router_ CCIP router address.
    /// @param registry_ Local CredentialRegistry address.
    function initialize(address admin, address router_, address registry_) external initializer {
        if (admin == address(0)) revert InvalidAdmin(admin);
        if (router_ == address(0)) revert InvalidRouter(router_);
        if (registry_ == address(0)) revert InvalidRegistry(registry_);

        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(SENDER_ROLE, admin);

        ccipRouter = ICCIPRouter(router_);
        credentialRegistry = ICredentialRegistry(registry_);
    }

    // ── Core: send credential ────────────────────────────────────────────
    /// @inheritdoc ITLHCCIPSender
    function sendCredential(
        uint64 destChainSelector,
        bytes32 subjectDID,
        bytes32 predicateType
    ) external payable onlyRole(SENDER_ROLE) nonReentrant returns (bytes32 messageId) {
        if (!allowedDestinations[destChainSelector]) revert DestinationNotAllowed(destChainSelector);
        address receiver = allowedReceivers[destChainSelector];
        if (receiver == address(0)) revert ReceiverNotSet(destChainSelector);

        // Consume nonce
        uint256 nonce = _nonces[destChainSelector]++;

        // Build CCIP message
        CCIPTypes.EVM2AnyMessage memory ccipMessage = _buildMessage(receiver, subjectDID, predicateType, nonce);

        // Get fee and validate
        uint256 fee = ccipRouter.getFee(destChainSelector, ccipMessage);
        if (msg.value < fee) revert InsufficientFee(fee, msg.value);

        // Send via CCIP
        messageId = ccipRouter.ccipSend{value: fee}(destChainSelector, ccipMessage);

        emit CredentialSent(messageId, destChainSelector, subjectDID, predicateType, nonce, fee);

        // M-3 fix: Refund excess ETH — don't revert after CCIP send
        uint256 excess = msg.value - fee;
        if (excess > 0) {
            (bool ok,) = msg.sender.call{value: excess}("");
            if (!ok) {
                // Track failed refund instead of reverting (CCIP message already sent)
                unclaimedRefunds[msg.sender] += excess;
                emit RefundFailed(msg.sender, excess);
            }
        }
    }

    // ── Core: estimate fee ───────────────────────────────────────────────
    /// @inheritdoc ITLHCCIPSender
    function estimateFee(
        uint64 destChainSelector,
        bytes32 subjectDID,
        bytes32 predicateType
    ) external view returns (uint256 fee) {
        address receiver = allowedReceivers[destChainSelector];
        uint256 nonce = _nonces[destChainSelector];

        CCIPTypes.EVM2AnyMessage memory ccipMessage = _buildMessage(receiver, subjectDID, predicateType, nonce);
        fee = ccipRouter.getFee(destChainSelector, ccipMessage);
    }

    // ── View: next nonce ─────────────────────────────────────────────────
    /// @inheritdoc ITLHCCIPSender
    function getNextNonce(uint64 destChainSelector) external view returns (uint256) {
        return _nonces[destChainSelector];
    }

    // ── Admin: configure destination ─────────────────────────────────────
    /// @notice Enable/disable a destination chain and set its receiver address.
    /// @param destChainSelector CCIP destination chain selector.
    /// @param receiver Receiver contract address on the destination chain.
    /// @param enabled Whether this destination is enabled.
    function configureDestination(
        uint64 destChainSelector,
        address receiver,
        bool enabled
    ) external onlyRole(ADMIN_ROLE) {
        allowedDestinations[destChainSelector] = enabled;
        allowedReceivers[destChainSelector] = receiver;
        emit DestinationConfigured(destChainSelector, receiver, enabled);
    }

    // ── Internal: build CCIP message ────────────────────────────────────
    /// @dev C-5 fix: Reads actual credential data from CredentialRegistry instead of fabricating values.
    function _buildMessage(
        address receiver,
        bytes32 subjectDID,
        bytes32 predicateType,
        uint256 nonce
    ) internal view returns (CCIPTypes.EVM2AnyMessage memory) {
        // Read real credential state from the registry
        (bool valid, uint256 expiresAt) = credentialRegistry.getCredentialInfo(subjectDID, predicateType);
        if (!valid) revert CredentialNotValid(subjectDID, predicateType);

        bytes memory payload = abi.encode(
            PROTOCOL_VERSION,
            nonce,
            subjectDID,
            predicateType,
            valid,
            expiresAt,
            keccak256(abi.encode(subjectDID, predicateType, nonce))
        );

        return CCIPTypes.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: payload,
            tokenAmounts: new CCIPTypes.EVMTokenAmount[](0),
            feeToken: address(0),
            extraArgs: CCIPTypes._argsToBytes(CCIPTypes.EVMExtraArgsV1({gasLimit: CCIP_GAS_LIMIT}))
        });
    }

    // ── ETH recovery ────────────────────────────────────────────────────
    /// @notice M-3 fix: Claim any unclaimed refunds from failed automatic refunds.
    function claimRefund() external nonReentrant {
        uint256 amount = unclaimedRefunds[msg.sender];
        require(amount > 0, "No unclaimed refund");

        unclaimedRefunds[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "Refund claim failed");
    }

    /// @notice Accept ETH (e.g. CCIP refunds).
    receive() external payable {}

    /// @notice Withdraw accumulated ETH to admin.
    function withdrawETH(address payable to) external onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        (bool ok,) = to.call{value: balance}("");
        require(ok, "withdraw failed");
    }

    // ── UUPS authorization ───────────────────────────────────────────────
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ── Storage gap ──────────────────────────────────────────────────────
    uint256[50] private __gap;
}
