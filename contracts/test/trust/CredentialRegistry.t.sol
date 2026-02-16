// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {CredentialRegistry} from "../../src/trust/CredentialRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract CredentialRegistryTest is Test {
    CredentialRegistry internal registry;

    address internal admin = address(0xA1);
    address internal verifierAddr = address(0xA2);
    address internal stranger = address(0xA3);

    bytes32 internal constant DID1 = keccak256("did:tlh:clinician-1");
    bytes32 internal constant DID2 = keccak256("did:tlh:clinician-2");
    bytes32 internal constant PRED_GMC = keccak256("GMC_REGISTERED");
    bytes32 internal constant PRED_BLS = keccak256("BLS_REGISTERED");
    bytes32 internal constant ATT_ID1 = keccak256("att-1");
    bytes32 internal constant ATT_ID2 = keccak256("att-2");

    function setUp() public {
        vm.warp(1_700_000_000);

        CredentialRegistry impl = new CredentialRegistry();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin));
        registry = CredentialRegistry(address(proxy));

        // Grant VERIFIER_ROLE to verifierAddr
        vm.prank(admin);
        registry.grantVerifier(verifierAddr);
    }

    // ---- initialization ----

    function testImplCannotBeReinitialized() public {
        CredentialRegistry impl = new CredentialRegistry();
        vm.expectRevert();
        impl.initialize(admin);
    }

    function testProxyCannotBeReinitialized() public {
        vm.expectRevert();
        registry.initialize(admin);
    }

    function testZeroAdminInitReverts() public {
        CredentialRegistry impl = new CredentialRegistry();
        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.InvalidAdmin.selector, address(0)));
        new ERC1967Proxy(address(impl), abi.encodeWithSelector(CredentialRegistry.initialize.selector, address(0)));
    }

    // ---- writeCredential ----

    function testWriteCredentialHappyPath() public {
        uint256 expiresAt = block.timestamp + 365 days;

        vm.prank(verifierAddr);
        vm.expectEmit(true, true, false, true);
        emit CredentialRegistry.CredentialWritten(DID1, PRED_GMC, true, ATT_ID1, block.timestamp);
        registry.writeCredential(DID1, PRED_GMC, true, expiresAt, ATT_ID1);

        CredentialRegistry.Credential memory c = registry.getCredential(DID1, PRED_GMC);
        assertEq(c.subjectDID, DID1);
        assertEq(c.predicateType, PRED_GMC);
        assertTrue(c.valid);
        assertEq(c.checkedAt, block.timestamp);
        assertEq(c.expiresAt, expiresAt);
        assertEq(c.attestationId, ATT_ID1);
        assertEq(uint256(c.status), uint256(CredentialRegistry.CredentialStatus.Active));
    }

    function testWriteCredentialSetsActiveNotExpired() public {
        // Write with valid=true but already-expired timestamp — storage status should be Active
        uint256 expiredAt = block.timestamp - 1;

        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, expiredAt, ATT_ID1);

        // Direct storage check: status should be Active at write-time
        // But getCredential should show Expired via _withLiveStatus
        CredentialRegistry.Credential memory c = registry.getCredential(DID1, PRED_GMC);
        assertEq(uint256(c.status), uint256(CredentialRegistry.CredentialStatus.Expired));
        assertFalse(c.valid); // _withLiveStatus sets valid=false for expired
    }

    function testWriteCredentialNonExpiringValid() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, 0, ATT_ID1);

        assertTrue(registry.isCredentialValid(DID1, PRED_GMC));
    }

    function testWriteCredentialUpdatesExisting() public {
        vm.startPrank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.warp(block.timestamp + 1 days);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID2);
        vm.stopPrank();

        CredentialRegistry.Credential memory c = registry.getCredential(DID1, PRED_GMC);
        assertEq(c.attestationId, ATT_ID2);
        assertEq(c.checkedAt, block.timestamp);
    }

    function testWriteCredentialStrangerReverts() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.UnauthorizedCredentialWriter.selector, stranger));
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);
    }

    function testWriteCredentialPreservesRevokedStatus() public {
        vm.startPrank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);
        vm.stopPrank();

        // Admin revokes
        vm.prank(admin);
        registry.revokeCredential(DID1, PRED_GMC);

        // Verifier writes again — revoked status must be preserved
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID2);

        assertFalse(registry.isCredentialValid(DID1, PRED_GMC));
    }

    // ---- getCredential ----

    function testGetCredentialNotFoundReverts() public {
        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.CredentialNotFound.selector, DID1, PRED_GMC));
        registry.getCredential(DID1, PRED_GMC);
    }

    // ---- getCredentialsByDID ----

    function testGetCredentialsByDIDMultiplePredicates() public {
        vm.startPrank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);
        registry.writeCredential(DID1, PRED_BLS, true, block.timestamp + 180 days, ATT_ID2);
        vm.stopPrank();

        CredentialRegistry.Credential[] memory creds = registry.getCredentialsByDID(DID1);
        assertEq(creds.length, 2);
        assertEq(creds[0].predicateType, PRED_GMC);
        assertEq(creds[1].predicateType, PRED_BLS);
    }

    function testGetCredentialsByDIDEmptyForUnknown() public view {
        CredentialRegistry.Credential[] memory creds = registry.getCredentialsByDID(keccak256("did:unknown"));
        assertEq(creds.length, 0);
    }

    function testGetCredentialsByDIDNoDuplicateIndex() public {
        // Write the same predicate twice — index should not grow
        vm.startPrank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID2);
        vm.stopPrank();

        CredentialRegistry.Credential[] memory creds = registry.getCredentialsByDID(DID1);
        assertEq(creds.length, 1);
    }

    // ---- revokeCredential ----

    function testRevokeCredentialByVerifier() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.prank(verifierAddr);
        vm.expectEmit(true, true, false, true);
        emit CredentialRegistry.CredentialRevoked(DID1, PRED_GMC, block.timestamp);
        registry.revokeCredential(DID1, PRED_GMC);

        assertFalse(registry.isCredentialValid(DID1, PRED_GMC));
    }

    function testRevokeCredentialByAdmin() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.prank(admin);
        registry.revokeCredential(DID1, PRED_GMC);

        assertFalse(registry.isCredentialValid(DID1, PRED_GMC));
    }

    function testRevokeCredentialStrangerReverts() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.UnauthorizedCredentialWriter.selector, stranger));
        registry.revokeCredential(DID1, PRED_GMC);
    }

    function testRevokeCredentialNotFoundReverts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.CredentialNotFound.selector, DID1, PRED_GMC));
        registry.revokeCredential(DID1, PRED_GMC);
    }

    function testDoubleRevokeReverts() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.startPrank(admin);
        registry.revokeCredential(DID1, PRED_GMC);

        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.CredentialAlreadyRevoked.selector, DID1, PRED_GMC));
        registry.revokeCredential(DID1, PRED_GMC);
        vm.stopPrank();
    }

    // ---- isCredentialValid ----

    function testIsCredentialValidReturnsFalseForUnknown() public view {
        assertFalse(registry.isCredentialValid(DID1, PRED_GMC));
    }

    function testIsCredentialValidExpired() public {
        uint256 expiresAt = block.timestamp + 1 days;

        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, expiresAt, ATT_ID1);

        // Before expiry: valid
        assertTrue(registry.isCredentialValid(DID1, PRED_GMC));

        // After expiry: invalid
        vm.warp(expiresAt + 1);
        assertFalse(registry.isCredentialValid(DID1, PRED_GMC));
    }

    function testIsCredentialValidRevoked() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.prank(admin);
        registry.revokeCredential(DID1, PRED_GMC);

        assertFalse(registry.isCredentialValid(DID1, PRED_GMC));
    }

    // ---- getCredential live status ----

    function testGetCredentialShowsExpiredAfterExpiry() public {
        uint256 expiresAt = block.timestamp + 1 days;

        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, expiresAt, ATT_ID1);

        vm.warp(expiresAt + 1);
        CredentialRegistry.Credential memory c = registry.getCredential(DID1, PRED_GMC);
        assertEq(uint256(c.status), uint256(CredentialRegistry.CredentialStatus.Expired));
        assertFalse(c.valid);
    }

    function testGetCredentialShowsRevokedAfterRevoke() public {
        vm.prank(verifierAddr);
        registry.writeCredential(DID1, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);

        vm.prank(admin);
        registry.revokeCredential(DID1, PRED_GMC);

        CredentialRegistry.Credential memory c = registry.getCredential(DID1, PRED_GMC);
        assertEq(uint256(c.status), uint256(CredentialRegistry.CredentialStatus.Revoked));
        assertFalse(c.valid);
    }

    // ---- upgrade authorization ----

    function testUpgradeOnlyUpgrader() public {
        CredentialRegistry newImpl = new CredentialRegistry();

        // Stranger cannot upgrade
        vm.prank(stranger);
        vm.expectRevert();
        registry.upgradeToAndCall(address(newImpl), "");

        // Verifier cannot upgrade
        vm.prank(verifierAddr);
        vm.expectRevert();
        registry.upgradeToAndCall(address(newImpl), "");

        // Admin (UPGRADER_ROLE) can upgrade
        vm.prank(admin);
        registry.upgradeToAndCall(address(newImpl), "");
    }

    // ---- grantVerifier ----

    function testGrantVerifierAdminOnly() public {
        address newVerifier = address(0xBEEF);

        vm.prank(stranger);
        vm.expectRevert();
        registry.grantVerifier(newVerifier);

        vm.prank(admin);
        registry.grantVerifier(newVerifier);

        // New verifier can now write
        vm.prank(newVerifier);
        registry.writeCredential(DID2, PRED_GMC, true, block.timestamp + 365 days, ATT_ID1);
        assertTrue(registry.isCredentialValid(DID2, PRED_GMC));
    }

    function testGrantVerifierZeroAddressReverts() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(CredentialRegistry.InvalidVerifier.selector, address(0)));
        registry.grantVerifier(address(0));
    }
}
