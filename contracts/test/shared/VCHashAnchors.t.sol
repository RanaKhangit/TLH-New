// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {VCHashAnchors} from "../../src/shared/VCHashAnchors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VCHashAnchorsTest is Test {
    VCHashAnchors anchors;

    address admin = address(0xA11CE);
    address writer = address(0xBEEF);

    bytes32 subjectDID = keccak256("did:example:123");
    bytes32 vcType = keccak256("MedicalLicense");
    bytes32 contentHash = keccak256("vc-content-hash-1");
    bytes32 contentHash2 = keccak256("vc-content-hash-2");

    function setUp() public {
        VCHashAnchors impl = new VCHashAnchors();
        bytes memory initData = abi.encodeCall(VCHashAnchors.initialize, (admin));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        anchors = VCHashAnchors(address(proxy));

        vm.startPrank(admin);
        anchors.grantRole(anchors.ANCHOR_WRITER_ROLE(), writer);
        vm.stopPrank();
    }

    function testAnchorHashSuccess() public {
        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash);

        (bytes32 hash, uint256 at, bool revoked) = anchors.getAnchor(subjectDID, vcType);
        assertEq(hash, contentHash);
        assertGt(at, 0);
        assertFalse(revoked);
    }

    function testRevokeAnchorSuccess() public {
        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash);

        vm.prank(admin);
        anchors.revokeAnchor(subjectDID, vcType);

        (,, bool revoked) = anchors.getAnchor(subjectDID, vcType);
        assertTrue(revoked);
    }

    /// @dev F-14: Revoked anchor cannot be overwritten by anchorHash
    function testAnchorHashRevertsOnRevokedAnchor() public {
        // Anchor, then revoke
        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash);

        vm.prank(admin);
        anchors.revokeAnchor(subjectDID, vcType);

        // Attempt to re-anchor — must revert with AnchorIsRevoked
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorIsRevoked.selector, subjectDID, vcType));
        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash2);

        // Verify original anchor is still revoked, unchanged
        (bytes32 hash,, bool revoked) = anchors.getAnchor(subjectDID, vcType);
        assertEq(hash, contentHash);
        assertTrue(revoked);
    }

    function testAnchorHashUpdatesNonRevokedAnchor() public {
        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash);

        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash2);

        (bytes32 hash,, bool revoked) = anchors.getAnchor(subjectDID, vcType);
        assertEq(hash, contentHash2);
        assertFalse(revoked);
    }

    function testRevokeAlreadyRevokedReverts() public {
        vm.prank(writer);
        anchors.anchorHash(subjectDID, vcType, contentHash);

        vm.prank(admin);
        anchors.revokeAnchor(subjectDID, vcType);

        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorAlreadyRevoked.selector, subjectDID, vcType));
        vm.prank(admin);
        anchors.revokeAnchor(subjectDID, vcType);
    }

    function testUnauthorizedWriterReverts() public {
        address rando = address(0xCAFE);
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.UnauthorizedAnchorWriter.selector, rando));
        vm.prank(rando);
        anchors.anchorHash(subjectDID, vcType, contentHash);
    }
}
