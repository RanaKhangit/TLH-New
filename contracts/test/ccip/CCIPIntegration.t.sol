// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TLHCCIPSender} from "../../src/ccip/TLHCCIPSender.sol";
import {TLHCCIPReceiver} from "../../src/ccip/TLHCCIPReceiver.sol";
import {CCIPTypes} from "../../src/ccip/CCIPTypes.sol";
import {CredentialRegistry} from "../../src/trust/CredentialRegistry.sol";
import {MockCCIPRouter} from "./mocks/MockCCIPRouter.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title CCIPIntegrationTest
/// @notice End-to-end integration test simulating cross-chain credential transfer.
///         Uses MockCCIPRouter in auto-deliver mode: ccipSend instantly delivers
///         the message to the receiver on the same chain, simulating the CCIP relay.
contract CCIPIntegrationTest is Test {
    TLHCCIPSender internal sender;
    TLHCCIPReceiver internal receiver;
    CredentialRegistry internal sourceRegistry;
    CredentialRegistry internal destRegistry;
    MockCCIPRouter internal router;

    address internal admin = address(0xA1);
    address internal senderRole = address(0xA2);

    // Using Arbitrum Sepolia → Ethereum Sepolia
    uint64 internal constant SOURCE_CHAIN = 3478487238524512106;
    uint64 internal constant DEST_CHAIN = 16015286601757825753;

    bytes32 internal constant DID1 = keccak256("did:tlh:clinician-1");
    bytes32 internal constant DID2 = keccak256("did:tlh:clinician-2");
    bytes32 internal constant PRED_GMC = keccak256("GMC_REGISTERED");
    bytes32 internal constant PRED_BLS = keccak256("BLS_REGISTERED");

    function setUp() public {
        vm.warp(1_700_000_000);

        // Deploy shared router (simulates both source and dest routers)
        router = new MockCCIPRouter();
        router.setAutoDeliver(true);

        // Deploy source chain registry
        CredentialRegistry srcImpl = new CredentialRegistry();
        ERC1967Proxy srcProxy = new ERC1967Proxy(
            address(srcImpl), abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin)
        );
        sourceRegistry = CredentialRegistry(address(srcProxy));

        // Deploy destination chain registry
        CredentialRegistry destImpl = new CredentialRegistry();
        ERC1967Proxy destProxy = new ERC1967Proxy(
            address(destImpl), abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin)
        );
        destRegistry = CredentialRegistry(address(destProxy));

        // Deploy sender (source chain)
        TLHCCIPSender senderImpl = new TLHCCIPSender();
        ERC1967Proxy senderProxy = new ERC1967Proxy(
            address(senderImpl),
            abi.encodeWithSelector(TLHCCIPSender.initialize.selector, admin, address(router), address(sourceRegistry))
        );
        sender = TLHCCIPSender(payable(address(senderProxy)));

        // Deploy receiver (destination chain)
        TLHCCIPReceiver receiverImpl = new TLHCCIPReceiver();
        ERC1967Proxy receiverProxy = new ERC1967Proxy(
            address(receiverImpl),
            abi.encodeWithSelector(
                TLHCCIPReceiver.initialize.selector, admin, address(router), address(destRegistry)
            )
        );
        receiver = TLHCCIPReceiver(payable(address(receiverProxy)));

        // Configure sender: allow dest chain, set receiver address
        vm.startPrank(admin);
        sender.grantRole(sender.SENDER_ROLE(), senderRole);
        sender.configureDestination(DEST_CHAIN, address(receiver), true);
        vm.stopPrank();

        // Configure receiver: allow source chain + sender
        // Note: In the mock auto-deliver, sourceChainSelector = destChainSelector
        // and sender = address(sender contract)
        vm.startPrank(admin);
        receiver.configureSourceChain(DEST_CHAIN, true);
        receiver.configureSender(DEST_CHAIN, address(sender), true);
        destRegistry.grantVerifier(address(receiver));
        vm.stopPrank();

        // Fund
        vm.deal(senderRole, 10 ether);
    }

    function testEndToEndCredentialTransfer() public {
        // Before: credential does not exist on destination
        assertFalse(destRegistry.isCredentialValid(DID1, PRED_GMC));

        // Send credential cross-chain
        vm.prank(senderRole);
        bytes32 messageId = sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID1, PRED_GMC);

        assertTrue(messageId != bytes32(0));

        // After: credential exists on destination registry
        assertTrue(destRegistry.isCredentialValid(DID1, PRED_GMC));

        // Verify credential details
        CredentialRegistry.Credential memory c = destRegistry.getCredential(DID1, PRED_GMC);
        assertEq(c.subjectDID, DID1);
        assertEq(c.predicateType, PRED_GMC);
        assertTrue(c.valid);
        assertEq(c.expiresAt, block.timestamp + 365 days);
    }

    function testMultipleSequentialTransfers() public {
        vm.startPrank(senderRole);

        // Transfer 1: DID1 + GMC
        sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID1, PRED_GMC);
        assertTrue(destRegistry.isCredentialValid(DID1, PRED_GMC));
        assertEq(sender.getNextNonce(DEST_CHAIN), 1);
        assertEq(receiver.getLastNonce(DEST_CHAIN), 1);

        // Transfer 2: DID1 + BLS
        sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID1, PRED_BLS);
        assertTrue(destRegistry.isCredentialValid(DID1, PRED_BLS));
        assertEq(sender.getNextNonce(DEST_CHAIN), 2);
        assertEq(receiver.getLastNonce(DEST_CHAIN), 2);

        // Transfer 3: DID2 + GMC
        sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID2, PRED_GMC);
        assertTrue(destRegistry.isCredentialValid(DID2, PRED_GMC));
        assertEq(sender.getNextNonce(DEST_CHAIN), 3);
        assertEq(receiver.getLastNonce(DEST_CHAIN), 3);

        vm.stopPrank();
    }

    function testCredentialValidOnDestChain() public {
        vm.prank(senderRole);
        sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID1, PRED_GMC);

        // isCredentialValid should return true
        assertTrue(destRegistry.isCredentialValid(DID1, PRED_GMC));

        // getCredentialsByDID should return the credential
        CredentialRegistry.Credential[] memory creds = destRegistry.getCredentialsByDID(DID1);
        assertEq(creds.length, 1);
        assertEq(creds[0].subjectDID, DID1);
        assertEq(creds[0].predicateType, PRED_GMC);
    }

    function testCredentialExpiresOnDestChain() public {
        vm.prank(senderRole);
        sender.sendCredential{value: 1 ether}(DEST_CHAIN, DID1, PRED_GMC);

        // Valid now
        assertTrue(destRegistry.isCredentialValid(DID1, PRED_GMC));

        // Fast-forward past expiry (365 days + 1 second)
        vm.warp(block.timestamp + 365 days + 1);
        assertFalse(destRegistry.isCredentialValid(DID1, PRED_GMC));
    }
}
