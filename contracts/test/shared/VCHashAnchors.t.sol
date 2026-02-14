// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {VCHashAnchors} from "../../src/shared/VCHashAnchors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract VCHashAnchorsTest is Test {
    VCHashAnchors internal vc;

    address internal admin = address(0xA1);
    address internal writer = address(0xA2);
    address internal stranger = address(0xA3);

    bytes32 internal constant DID1 = keccak256("did:tlh:clinician-1");
    bytes32 internal constant VC_TYPE = keccak256("GMC_LICENSE");
    bytes32 internal constant HASH_A = keccak256("content-hash-A");
    bytes32 internal constant HASH_B = keccak256("content-hash-B");

    function setUp() public {
        vm.warp(1_700_000_000);

        VCHashAnchors impl = new VCHashAnchors();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeWithSelector(VCHashAnchors.initialize.selector, admin));
        vc = VCHashAnchors(address(proxy));

        vm.startPrank(admin);
        vc.grantRole(vc.ANCHOR_WRITER_ROLE(), writer);
        vm.stopPrank();
    }

    // ---- initialization ----

    function testZeroAdminInitReverts() public {
        VCHashAnchors impl = new VCHashAnchors();
        vm.expectRevert(VCHashAnchors.ZeroAdminAddress.selector);
        new ERC1967Proxy(address(impl), abi.encodeWithSelector(VCHashAnchors.initialize.selector, address(0)));
    }

    function testImplCannotBeReinitialized() public {
        VCHashAnchors impl = new VCHashAnchors();
        vm.expectRevert();
        impl.initialize(admin);
    }

    // ---- anchor happy path ----

    function testAnchorHappyPath() public {
        vm.prank(writer);
        vm.expectEmit(true, true, false, true);
        emit VCHashAnchors.HashAnchored(DID1, VC_TYPE, HASH_A, block.timestamp);
        vc.anchorHash(DID1, VC_TYPE, HASH_A);

        (bytes32 contentHash, uint256 anchoredAt, bool revoked) = vc.getAnchor(DID1, VC_TYPE);
        assertEq(contentHash, HASH_A);
        assertEq(anchoredAt, block.timestamp);
        assertFalse(revoked);
    }

    // ---- append-only history ----

    function testAppendOnlyHistory() public {
        vm.startPrank(writer);
        vc.anchorHash(DID1, VC_TYPE, HASH_A);

        vm.warp(block.timestamp + 1 days);
        vc.anchorHash(DID1, VC_TYPE, HASH_B);
        vm.stopPrank();

        bytes32[] memory history = vc.getAnchorHistory(DID1, VC_TYPE);
        assertEq(history.length, 2);
        assertEq(history[0], HASH_A);
        assertEq(history[1], HASH_B);

        // Latest record should reflect HASH_B
        (bytes32 latest,,) = vc.getAnchor(DID1, VC_TYPE);
        assertEq(latest, HASH_B);
    }

    // ---- revocation ----

    function testRevokeAnchorSetsRevokedFlag() public {
        vm.prank(writer);
        vc.anchorHash(DID1, VC_TYPE, HASH_A);

        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit VCHashAnchors.AnchorRevoked(DID1, VC_TYPE, block.timestamp);
        vc.revokeAnchor(DID1, VC_TYPE);

        (,, bool revoked) = vc.getAnchor(DID1, VC_TYPE);
        assertTrue(revoked);
    }

    function testRevokeBlocksReAnchor() public {
        vm.prank(writer);
        vc.anchorHash(DID1, VC_TYPE, HASH_A);

        vm.prank(admin);
        vc.revokeAnchor(DID1, VC_TYPE);

        vm.prank(writer);
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorAlreadyRevoked.selector, DID1, VC_TYPE));
        vc.anchorHash(DID1, VC_TYPE, HASH_B);
    }

    function testDoubleRevokeReverts() public {
        vm.prank(writer);
        vc.anchorHash(DID1, VC_TYPE, HASH_A);

        vm.startPrank(admin);
        vc.revokeAnchor(DID1, VC_TYPE);

        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorAlreadyRevoked.selector, DID1, VC_TYPE));
        vc.revokeAnchor(DID1, VC_TYPE);
        vm.stopPrank();
    }

    function testRevokeNonexistentReverts() public {
        bytes32 unknownDID = keccak256("did:unknown");
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorNotFound.selector, unknownDID, VC_TYPE));
        vc.revokeAnchor(unknownDID, VC_TYPE);
    }

    // ---- role enforcement ----

    function testNonWriterCannotAnchor() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.UnauthorizedAnchorWriter.selector, stranger));
        vc.anchorHash(DID1, VC_TYPE, HASH_A);
    }

    function testNonAdminCannotRevoke() public {
        vm.prank(writer);
        vc.anchorHash(DID1, VC_TYPE, HASH_A);

        vm.prank(stranger);
        vm.expectRevert();
        vc.revokeAnchor(DID1, VC_TYPE);
    }

    // ---- getAnchor on non-existent ----

    function testGetAnchorNotFoundReverts() public {
        bytes32 unknownDID = keccak256("did:unknown");
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorNotFound.selector, unknownDID, VC_TYPE));
        vc.getAnchor(unknownDID, VC_TYPE);
    }

    // ---- history on non-existent returns empty ----

    function testGetHistoryEmptyForUnknown() public view {
        bytes32[] memory history = vc.getAnchorHistory(keccak256("did:unknown"), VC_TYPE);
        assertEq(history.length, 0);
    }

    // ---- upgrade authorization ----

    function testUpgradeOnlyUpgrader() public {
        VCHashAnchors newImpl = new VCHashAnchors();

        // Stranger cannot upgrade
        vm.prank(stranger);
        vm.expectRevert();
        vc.upgradeToAndCall(address(newImpl), "");

        // Writer cannot upgrade
        vm.prank(writer);
        vm.expectRevert();
        vc.upgradeToAndCall(address(newImpl), "");

        // Admin (who has UPGRADER_ROLE) can upgrade
        vm.prank(admin);
        vc.upgradeToAndCall(address(newImpl), "");
    }
}
