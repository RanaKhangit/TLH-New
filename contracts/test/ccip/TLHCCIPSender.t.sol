// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TLHCCIPSender} from "../../src/ccip/TLHCCIPSender.sol";
import {CCIPTypes} from "../../src/ccip/CCIPTypes.sol";
import {CredentialRegistry} from "../../src/trust/CredentialRegistry.sol";
import {MockCCIPRouter} from "./mocks/MockCCIPRouter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TLHCCIPSenderTest is Test {
    TLHCCIPSender internal sender;
    MockCCIPRouter internal router;
    CredentialRegistry internal registry;

    address internal admin = address(0xA1);
    address internal senderRole = address(0xA2);
    address internal stranger = address(0xA3);
    address internal receiverAddr = address(0xBEEF);

    uint64 internal constant DEST_CHAIN = 16015286601757825753; // Sepolia selector

    bytes32 internal constant DID1 = keccak256("did:tlh:clinician-1");
    bytes32 internal constant PRED_GMC = keccak256("GMC_REGISTERED");

    function setUp() public {
        vm.warp(1_700_000_000);

        // Deploy mock router
        router = new MockCCIPRouter();

        // Deploy registry (for sender to reference)
        CredentialRegistry registryImpl = new CredentialRegistry();
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin)
        );
        registry = CredentialRegistry(address(registryProxy));

        // Deploy sender behind proxy
        TLHCCIPSender senderImpl = new TLHCCIPSender();
        ERC1967Proxy senderProxy = new ERC1967Proxy(
            address(senderImpl),
            abi.encodeWithSelector(
                TLHCCIPSender.initialize.selector, admin, address(router), address(registry)
            )
        );
        sender = TLHCCIPSender(payable(address(senderProxy)));

        // Grant SENDER_ROLE to senderRole address and configure destination
        vm.startPrank(admin);
        sender.grantRole(sender.SENDER_ROLE(), senderRole);
        sender.configureDestination(DEST_CHAIN, receiverAddr, true);
        vm.stopPrank();

        // Fund test accounts
        vm.deal(senderRole, 10 ether);
        vm.deal(admin, 10 ether);
        vm.deal(stranger, 10 ether);
    }

    // ---- initialization ----

    function testImplCannotBeReinitialized() public {
        TLHCCIPSender impl = new TLHCCIPSender();
        vm.expectRevert();
        impl.initialize(admin, address(router), address(registry));
    }

    function testProxyCannotBeReinitialized() public {
        vm.expectRevert();
        sender.initialize(admin, address(router), address(registry));
    }

    function testInitializeZeroAdminReverts() public {
        TLHCCIPSender impl = new TLHCCIPSender();
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPSender.InvalidAdmin.selector, address(0)));
        new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPSender.initialize.selector, address(0), address(router), address(registry))
        );
    }

    function testInitializeZeroRouterReverts() public {
        TLHCCIPSender impl = new TLHCCIPSender();
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPSender.InvalidRouter.selector, address(0)));
        new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPSender.initialize.selector, admin, address(0), address(registry))
        );
    }

    function testInitializeZeroRegistryReverts() public {
        TLHCCIPSender impl = new TLHCCIPSender();
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPSender.InvalidRegistry.selector, address(0)));
        new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPSender.initialize.selector, admin, address(router), address(0))
        );
    }

    // ---- sendCredential happy path ----

    function testSendCredentialHappyPath() public {
        vm.prank(senderRole);
        vm.expectEmit(false, true, true, false); // messageId is unpredictable
        emit TLHCCIPSender.CredentialSent(bytes32(0), DEST_CHAIN, DID1, PRED_GMC, 0, 0.01 ether);
        bytes32 messageId = sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);

        assertTrue(messageId != bytes32(0));
        assertEq(sender.getNextNonce(DEST_CHAIN), 1);
    }

    function testSendCredentialPayloadEncoding() public {
        vm.prank(senderRole);
        sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);

        // Verify the message sent to the router
        assertEq(router.lastDestChainSelector(), DEST_CHAIN);

        // Decode the data payload from the mock router's stored message
        CCIPTypes.EVM2AnyMessage memory msg_ = router.getLastMessage();
        (
            bytes32 protocolVersion,
            uint256 nonce,
            bytes32 subjectDID,
            bytes32 predicateType,
            bool valid,
            ,
            bytes32 attestationId
        ) = abi.decode(msg_.data, (bytes32, uint256, bytes32, bytes32, bool, uint256, bytes32));

        assertEq(protocolVersion, sender.PROTOCOL_VERSION());
        assertEq(nonce, 0);
        assertEq(subjectDID, DID1);
        assertEq(predicateType, PRED_GMC);
        assertTrue(valid);
        assertEq(attestationId, keccak256(abi.encodePacked(DID1, PRED_GMC, uint256(0))));
    }

    // ---- nonce management ----

    function testNonceIncrementsPerDestination() public {
        assertEq(sender.getNextNonce(DEST_CHAIN), 0);

        vm.startPrank(senderRole);
        sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);
        assertEq(sender.getNextNonce(DEST_CHAIN), 1);

        sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);
        assertEq(sender.getNextNonce(DEST_CHAIN), 2);

        sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);
        assertEq(sender.getNextNonce(DEST_CHAIN), 3);
        vm.stopPrank();
    }

    function testNonceIsolatedPerDestination() public {
        uint64 otherChain = 3478487238524512106; // Arbitrum Sepolia

        vm.prank(admin);
        sender.configureDestination(otherChain, address(0xCAFE), true);

        vm.startPrank(senderRole);
        sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);
        sender.sendCredential{value: 0.1 ether}(otherChain, DID1, PRED_GMC);
        vm.stopPrank();

        assertEq(sender.getNextNonce(DEST_CHAIN), 1);
        assertEq(sender.getNextNonce(otherChain), 1);
    }

    // ---- fee and refund ----

    function testEstimateFee() public view {
        uint256 fee = sender.estimateFee(DEST_CHAIN, DID1, PRED_GMC);
        assertEq(fee, router.FIXED_FEE());
    }

    function testRefundExcessETH() public {
        uint256 balanceBefore = senderRole.balance;

        vm.prank(senderRole);
        sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID1, PRED_GMC);

        uint256 balanceAfter = senderRole.balance;
        // Should have only spent 0.01 ether (FIXED_FEE)
        assertEq(balanceBefore - balanceAfter, router.FIXED_FEE());
    }

    function testRevertInsufficientFee() public {
        uint256 fixedFee = router.FIXED_FEE();
        vm.expectRevert(
            abi.encodeWithSelector(TLHCCIPSender.InsufficientFee.selector, fixedFee, 0.001 ether)
        );
        vm.prank(senderRole);
        sender.sendCredential{value: 0.001 ether}(DEST_CHAIN, DID1, PRED_GMC);
    }

    // ---- access control ----

    function testRevertUnauthorizedSender() public {
        vm.prank(stranger);
        vm.expectRevert();
        sender.sendCredential{value: 0.1 ether}(DEST_CHAIN, DID1, PRED_GMC);
    }

    function testConfigureDestinationAdminOnly() public {
        vm.prank(stranger);
        vm.expectRevert();
        sender.configureDestination(DEST_CHAIN, address(0xDEAD), false);

        // Admin can configure
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit TLHCCIPSender.DestinationConfigured(DEST_CHAIN, address(0xDEAD), false);
        sender.configureDestination(DEST_CHAIN, address(0xDEAD), false);

        assertFalse(sender.allowedDestinations(DEST_CHAIN));
        assertEq(sender.allowedReceivers(DEST_CHAIN), address(0xDEAD));
    }

    // ---- destination checks ----

    function testRevertDestinationNotAllowed() public {
        uint64 disabledChain = 999;
        vm.prank(senderRole);
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPSender.DestinationNotAllowed.selector, disabledChain));
        sender.sendCredential{value: 0.1 ether}(disabledChain, DID1, PRED_GMC);
    }

    function testRevertReceiverNotSet() public {
        uint64 noReceiverChain = 888;

        // Enable chain but don't set receiver
        vm.prank(admin);
        sender.configureDestination(noReceiverChain, address(0), true);

        vm.prank(senderRole);
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPSender.ReceiverNotSet.selector, noReceiverChain));
        sender.sendCredential{value: 0.1 ether}(noReceiverChain, DID1, PRED_GMC);
    }

    // ---- upgrade ----

    function testUpgradeOnlyUpgrader() public {
        TLHCCIPSender newImpl = new TLHCCIPSender();

        vm.prank(stranger);
        vm.expectRevert();
        sender.upgradeToAndCall(address(newImpl), "");

        vm.prank(admin);
        sender.upgradeToAndCall(address(newImpl), "");
    }
}
