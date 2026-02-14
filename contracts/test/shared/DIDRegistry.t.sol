// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DIDRegistry} from "../../src/shared/DIDRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DIDRegistryTest is Test {
    DIDRegistry internal registry;

    address internal admin = address(0xA1);
    address internal stranger = address(0xA3);

    bytes32 internal constant DID1 = keccak256("did:tlh:clinician-1");
    bytes32 internal constant DID2 = keccak256("did:tlh:clinician-2");

    function setUp() public {
        vm.warp(1_700_000_000);

        DIDRegistry impl = new DIDRegistry();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(impl), abi.encodeWithSelector(DIDRegistry.initialize.selector, admin));
        registry = DIDRegistry(address(proxy));
    }

    // ---- initialization ----

    function testImplCannotBeReinitialized() public {
        DIDRegistry impl = new DIDRegistry();
        vm.expectRevert();
        impl.initialize(admin);
    }

    function testProxyCannotBeReinitialized() public {
        vm.expectRevert();
        registry.initialize(admin);
    }

    function testZeroAdminInitReverts() public {
        DIDRegistry impl = new DIDRegistry();
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.InvalidAdmin.selector, address(0)));
        new ERC1967Proxy(address(impl), abi.encodeWithSelector(DIDRegistry.initialize.selector, address(0)));
    }

    function testProxyInitializesRolesCorrectly() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.REGISTRAR_ROLE(), admin));
        assertTrue(registry.hasRole(registry.UPGRADER_ROLE(), admin));
    }

    // ---- registerDID ----

    function testRegisterDIDHappyPath() public {
        vm.prank(admin);
        vm.expectEmit(true, true, false, true);
        emit DIDRegistry.DIDRegistered(DID1, address(0xBEEF), block.timestamp);
        registry.registerDID(DID1, address(0xBEEF));

        (address controller, bool active, uint256 registeredAt, uint256 updatedAt) = registry.resolveDID(DID1);
        assertEq(controller, address(0xBEEF));
        assertTrue(active);
        assertEq(registeredAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
    }

    function testRegisterDIDUpdatesLastUpdatedAtAndEmitsUnifiedEvent() public {
        uint256 tsBefore = registry.lastUpdatedAt();
        assertEq(tsBefore, 0);

        vm.warp(1_700_000_100);
        vm.prank(admin);

        vm.expectEmit(true, true, true, true);
        emit DIDRegistry.DIDRegistryUpdated(DID1, 1, admin, block.timestamp);
        registry.registerDID(DID1, address(0xBEEF));

        assertEq(registry.lastUpdatedAt(), 1_700_000_100);
    }

    function testRegisterDIDStrangerReverts() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.registerDID(DID1, address(0xBEEF));
    }

    function testRegisterDIDDuplicateReverts() public {
        vm.startPrank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyRegistered.selector, DID1));
        registry.registerDID(DID1, address(0xBEEF));
        vm.stopPrank();
    }

    // ---- resolveDID ----

    function testResolveDIDNotFoundReverts() public {
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, DID1));
        registry.resolveDID(DID1);
    }

    // ---- deactivateDID ----

    function testDeactivateDIDHappyPath() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, false, false, true);
        emit DIDRegistry.DIDDeactivated(DID1, block.timestamp);
        registry.deactivateDID(DID1);

        (, bool active,,) = registry.resolveDID(DID1);
        assertFalse(active);
    }

    function testDeactivateDIDUpdatesLastUpdatedAtAndEmitsUnifiedEvent() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_200);
        vm.prank(address(0xBEEF));

        vm.expectEmit(true, true, true, true);
        emit DIDRegistry.DIDRegistryUpdated(DID1, 2, address(0xBEEF), block.timestamp);
        registry.deactivateDID(DID1);

        assertEq(registry.lastUpdatedAt(), 1_700_000_200);
    }

    function testDeactivateDIDNotControllerReverts() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, DID1, stranger));
        registry.deactivateDID(DID1);
    }

    function testDeactivateDIDAlreadyDeactivatedReverts() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.startPrank(address(0xBEEF));
        registry.deactivateDID(DID1);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyDeactivated.selector, DID1));
        registry.deactivateDID(DID1);
        vm.stopPrank();
    }

    // ---- updateController ----

    function testUpdateControllerHappyPath() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.prank(address(0xBEEF));
        vm.expectEmit(true, true, true, false);
        emit DIDRegistry.DIDControllerUpdated(DID1, address(0xBEEF), address(0xCAFE));
        registry.updateController(DID1, address(0xCAFE));

        (address controller,,,) = registry.resolveDID(DID1);
        assertEq(controller, address(0xCAFE));
    }

    function testUpdateControllerUpdatesLastUpdatedAtAndEmitsUnifiedEvent() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_300);
        vm.prank(address(0xBEEF));

        vm.expectEmit(true, true, true, true);
        emit DIDRegistry.DIDRegistryUpdated(DID1, 3, address(0xBEEF), block.timestamp);
        registry.updateController(DID1, address(0xCAFE));

        assertEq(registry.lastUpdatedAt(), 1_700_000_300);
    }

    function testUpdateControllerNotControllerReverts() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, DID1, stranger));
        registry.updateController(DID1, address(0xCAFE));
    }

    // ---- lastUpdatedAt tracks across multiple mutations ----

    function testLastUpdatedAtTracksAcrossMutations() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));
        assertEq(registry.lastUpdatedAt(), 1_700_000_100);

        vm.warp(1_700_000_200);
        vm.prank(admin);
        registry.registerDID(DID2, address(0xCAFE));
        assertEq(registry.lastUpdatedAt(), 1_700_000_200);

        vm.warp(1_700_000_300);
        vm.prank(address(0xBEEF));
        registry.deactivateDID(DID1);
        assertEq(registry.lastUpdatedAt(), 1_700_000_300);

        vm.warp(1_700_000_400);
        vm.prank(address(0xCAFE));
        registry.updateController(DID2, address(0xDEAD));
        assertEq(registry.lastUpdatedAt(), 1_700_000_400);
    }

    // ---- upgrade authorization ----

    function testUpgradeOnlyUpgrader() public {
        DIDRegistry newImpl = new DIDRegistry();

        // Stranger cannot upgrade
        vm.prank(stranger);
        vm.expectRevert();
        registry.upgradeToAndCall(address(newImpl), "");

        // Admin (UPGRADER_ROLE) can upgrade
        vm.prank(admin);
        registry.upgradeToAndCall(address(newImpl), "");
    }
}
