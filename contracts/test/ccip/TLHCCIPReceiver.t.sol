// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TLHCCIPReceiver} from "../../src/ccip/TLHCCIPReceiver.sol";
import {CCIPTypes, ICCIPReceiver} from "../../src/ccip/CCIPTypes.sol";
import {CredentialRegistry} from "../../src/trust/CredentialRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TLHCCIPReceiverTest is Test {
    TLHCCIPReceiver internal receiver;
    CredentialRegistry internal registry;

    address internal admin = address(0xA1);
    address internal stranger = address(0xA3);
    address internal mockRouter = address(0xB0);
    address internal senderOnSource = address(0xBEEF);

    uint64 internal constant SOURCE_CHAIN = 3478487238524512106; // Arbitrum Sepolia selector
    bytes32 internal constant PROTOCOL_VERSION = keccak256("CCIP_TLH_V1");

    bytes32 internal constant DID1 = keccak256("did:tlh:clinician-1");
    bytes32 internal constant DID2 = keccak256("did:tlh:clinician-2");
    bytes32 internal constant PRED_GMC = keccak256("GMC_REGISTERED");
    bytes32 internal constant PRED_BLS = keccak256("BLS_REGISTERED");

    function setUp() public {
        vm.warp(1_700_000_000);

        // Deploy registry
        CredentialRegistry registryImpl = new CredentialRegistry();
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin)
        );
        registry = CredentialRegistry(address(registryProxy));

        // Deploy receiver behind proxy
        TLHCCIPReceiver receiverImpl = new TLHCCIPReceiver();
        ERC1967Proxy receiverProxy = new ERC1967Proxy(
            address(receiverImpl),
            abi.encodeWithSelector(
                TLHCCIPReceiver.initialize.selector, admin, mockRouter, address(registry)
            )
        );
        receiver = TLHCCIPReceiver(payable(address(receiverProxy)));

        // Grant VERIFIER_ROLE to receiver so it can write to registry
        vm.prank(admin);
        registry.grantVerifier(address(receiver));

        // Configure allowlists
        vm.startPrank(admin);
        receiver.configureSourceChain(SOURCE_CHAIN, true);
        receiver.configureSender(SOURCE_CHAIN, senderOnSource, true);
        vm.stopPrank();
    }

    // ── helpers ──────────────────────────────────────────────────────────

    function _buildPayload(
        uint256 nonce,
        bytes32 subjectDID,
        bytes32 predicateType
    ) internal view returns (bytes memory) {
        return abi.encode(
            PROTOCOL_VERSION,
            nonce,
            subjectDID,
            predicateType,
            true,
            block.timestamp + 365 days,
            keccak256(abi.encodePacked(subjectDID, predicateType, nonce))
        );
    }

    function _buildMessage(
        uint256 nonce,
        bytes32 subjectDID,
        bytes32 predicateType
    ) internal view returns (CCIPTypes.Any2EVMMessage memory) {
        return CCIPTypes.Any2EVMMessage({
            messageId: keccak256(abi.encodePacked("msg", nonce)),
            sourceChainSelector: SOURCE_CHAIN,
            sender: abi.encode(senderOnSource),
            data: _buildPayload(nonce, subjectDID, predicateType),
            destTokenAmounts: new CCIPTypes.EVMTokenAmount[](0)
        });
    }

    // ---- initialization ----

    function testImplCannotBeReinitialized() public {
        TLHCCIPReceiver impl = new TLHCCIPReceiver();
        vm.expectRevert();
        impl.initialize(admin, mockRouter, address(registry));
    }

    function testProxyCannotBeReinitialized() public {
        vm.expectRevert();
        receiver.initialize(admin, mockRouter, address(registry));
    }

    function testInitializeZeroAdminReverts() public {
        TLHCCIPReceiver impl = new TLHCCIPReceiver();
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPReceiver.InvalidAdmin.selector, address(0)));
        new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPReceiver.initialize.selector, address(0), mockRouter, address(registry))
        );
    }

    function testInitializeZeroRouterReverts() public {
        TLHCCIPReceiver impl = new TLHCCIPReceiver();
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPReceiver.InvalidRouter.selector, address(0)));
        new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPReceiver.initialize.selector, admin, address(0), address(registry))
        );
    }

    // ---- receive credential happy path ----

    function testReceiveCredentialHappyPath() public {
        CCIPTypes.Any2EVMMessage memory msg_ = _buildMessage(0, DID1, PRED_GMC);

        vm.prank(mockRouter);
        vm.expectEmit(true, true, true, true);
        emit TLHCCIPReceiver.CredentialReceivedViaCCIP(
            msg_.messageId, SOURCE_CHAIN, senderOnSource, DID1, PRED_GMC, 0
        );
        receiver.ccipReceive(msg_);

        // Verify credential was written to registry
        assertTrue(registry.isCredentialValid(DID1, PRED_GMC));
    }

    function testCredentialWrittenToRegistry() public {
        CCIPTypes.Any2EVMMessage memory msg_ = _buildMessage(0, DID1, PRED_GMC);

        vm.prank(mockRouter);
        receiver.ccipReceive(msg_);

        CredentialRegistry.Credential memory c = registry.getCredential(DID1, PRED_GMC);
        assertEq(c.subjectDID, DID1);
        assertEq(c.predicateType, PRED_GMC);
        assertTrue(c.valid);
        assertEq(c.expiresAt, block.timestamp + 365 days);
        assertEq(c.attestationId, keccak256(abi.encodePacked(DID1, PRED_GMC, uint256(0))));
    }

    // ---- only router ----

    function testRevertOnlyRouter() public {
        CCIPTypes.Any2EVMMessage memory msg_ = _buildMessage(0, DID1, PRED_GMC);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPReceiver.InvalidRouter.selector, stranger));
        receiver.ccipReceive(msg_);
    }

    // ---- source chain allowlist ----

    function testRevertSourceChainNotAllowed() public {
        uint64 unknownChain = 999;
        CCIPTypes.Any2EVMMessage memory msg_ = CCIPTypes.Any2EVMMessage({
            messageId: keccak256("msg-bad-chain"),
            sourceChainSelector: unknownChain,
            sender: abi.encode(senderOnSource),
            data: _buildPayload(0, DID1, PRED_GMC),
            destTokenAmounts: new CCIPTypes.EVMTokenAmount[](0)
        });

        vm.prank(mockRouter);
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPReceiver.SourceChainNotAllowed.selector, unknownChain));
        receiver.ccipReceive(msg_);
    }

    // ---- sender allowlist ----

    function testRevertSenderNotAllowed() public {
        address unknownSender = address(0xDEAD);
        CCIPTypes.Any2EVMMessage memory msg_ = CCIPTypes.Any2EVMMessage({
            messageId: keccak256("msg-bad-sender"),
            sourceChainSelector: SOURCE_CHAIN,
            sender: abi.encode(unknownSender),
            data: _buildPayload(0, DID1, PRED_GMC),
            destTokenAmounts: new CCIPTypes.EVMTokenAmount[](0)
        });

        vm.prank(mockRouter);
        vm.expectRevert(
            abi.encodeWithSelector(TLHCCIPReceiver.SenderNotAllowed.selector, SOURCE_CHAIN, unknownSender)
        );
        receiver.ccipReceive(msg_);
    }

    // ---- protocol version ----

    function testRevertInvalidProtocolVersion() public {
        bytes32 badVersion = keccak256("WRONG_V1");
        bytes memory badPayload = abi.encode(
            badVersion, uint256(0), DID1, PRED_GMC, true, block.timestamp + 365 days, keccak256("att")
        );

        CCIPTypes.Any2EVMMessage memory msg_ = CCIPTypes.Any2EVMMessage({
            messageId: keccak256("msg-bad-version"),
            sourceChainSelector: SOURCE_CHAIN,
            sender: abi.encode(senderOnSource),
            data: badPayload,
            destTokenAmounts: new CCIPTypes.EVMTokenAmount[](0)
        });

        vm.prank(mockRouter);
        vm.expectRevert(
            abi.encodeWithSelector(TLHCCIPReceiver.InvalidProtocolVersion.selector, PROTOCOL_VERSION, badVersion)
        );
        receiver.ccipReceive(msg_);
    }

    // ---- nonce validation ----

    function testRevertInvalidNonceDuplicate() public {
        // Send nonce 0
        vm.prank(mockRouter);
        receiver.ccipReceive(_buildMessage(0, DID1, PRED_GMC));

        // Try nonce 0 again (duplicate)
        vm.prank(mockRouter);
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPReceiver.InvalidNonce.selector, SOURCE_CHAIN, 1, 0));
        receiver.ccipReceive(_buildMessage(0, DID1, PRED_GMC));
    }

    function testRevertInvalidNonceGap() public {
        // Skip nonce 0, try nonce 2
        CCIPTypes.Any2EVMMessage memory msg_ = _buildMessage(2, DID1, PRED_GMC);

        vm.prank(mockRouter);
        vm.expectRevert(abi.encodeWithSelector(TLHCCIPReceiver.InvalidNonce.selector, SOURCE_CHAIN, 0, 2));
        receiver.ccipReceive(msg_);
    }

    function testSequentialNonces() public {
        vm.startPrank(mockRouter);

        receiver.ccipReceive(_buildMessage(0, DID1, PRED_GMC));
        assertEq(receiver.getLastNonce(SOURCE_CHAIN), 1);

        receiver.ccipReceive(_buildMessage(1, DID1, PRED_BLS));
        assertEq(receiver.getLastNonce(SOURCE_CHAIN), 2);

        receiver.ccipReceive(_buildMessage(2, DID2, PRED_GMC));
        assertEq(receiver.getLastNonce(SOURCE_CHAIN), 3);

        vm.stopPrank();
    }

    // ---- admin configuration ----

    function testConfigureSourceChainAdminOnly() public {
        vm.prank(stranger);
        vm.expectRevert();
        receiver.configureSourceChain(SOURCE_CHAIN, false);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit TLHCCIPReceiver.SourceChainConfigured(SOURCE_CHAIN, false);
        receiver.configureSourceChain(SOURCE_CHAIN, false);

        assertFalse(receiver.isChainAllowlisted(SOURCE_CHAIN));
    }

    function testConfigureSenderAdminOnly() public {
        address newSender = address(0xCAFE);

        vm.prank(stranger);
        vm.expectRevert();
        receiver.configureSender(SOURCE_CHAIN, newSender, true);

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit TLHCCIPReceiver.SenderConfigured(SOURCE_CHAIN, newSender, true);
        receiver.configureSender(SOURCE_CHAIN, newSender, true);

        assertTrue(receiver.isSenderAllowlisted(SOURCE_CHAIN, newSender));
    }

    // ---- view methods ----

    function testQueryMethods() public view {
        assertTrue(receiver.isChainAllowlisted(SOURCE_CHAIN));
        assertFalse(receiver.isChainAllowlisted(999));

        assertTrue(receiver.isSenderAllowlisted(SOURCE_CHAIN, senderOnSource));
        assertFalse(receiver.isSenderAllowlisted(SOURCE_CHAIN, stranger));

        assertEq(receiver.getLastNonce(SOURCE_CHAIN), 0);
        assertEq(receiver.getRouter(), mockRouter);
    }

    // ---- ERC-165 ----

    function testSupportsInterface() public view {
        // ICCIPReceiver interface
        assertTrue(receiver.supportsInterface(type(ICCIPReceiver).interfaceId));
        // IERC165
        assertTrue(receiver.supportsInterface(0x01ffc9a7));
        // Random interface — should be false
        assertFalse(receiver.supportsInterface(0xdeadbeef));
    }

    // ---- upgrade ----

    function testUpgradeOnlyUpgrader() public {
        TLHCCIPReceiver newImpl = new TLHCCIPReceiver();

        vm.prank(stranger);
        vm.expectRevert();
        receiver.upgradeToAndCall(address(newImpl), "");

        vm.prank(admin);
        receiver.upgradeToAndCall(address(newImpl), "");
    }
}
