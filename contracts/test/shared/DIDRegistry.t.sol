// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DIDRegistry} from "../../src/shared/DIDRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DIDRegistryTest is Test {
    DIDRegistry registry;

    address admin = address(0xA11CE);
    address registrar = address(0xBEEF);
    address controller = address(0xC0DE);
    address other = address(0xB0B);
    address newCtrl = address(0xDEAD);

    bytes32 did1 = keccak256("did:tlh:subject-1");
    bytes32 did2 = keccak256("did:tlh:subject-2");

    function setUp() public {
        vm.warp(1_700_000_000);

        DIDRegistry impl = new DIDRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(DIDRegistry.initialize, (admin)));
        registry = DIDRegistry(address(proxy));

        vm.startPrank(admin);
        registry.grantRole(registry.REGISTRAR_ROLE(), registrar);
        vm.stopPrank();
    }

    function testInitializeGrantsRoles() public view {
        assertTrue(registry.hasRole(registry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(registry.hasRole(registry.REGISTRAR_ROLE(), admin));
        assertTrue(registry.hasRole(registry.UPGRADER_ROLE(), admin));
    }

    function testInitializeZeroAddressReverts() public {
        DIDRegistry impl = new DIDRegistry();
        vm.expectRevert(DIDRegistry.InvalidAdmin.selector);
        new ERC1967Proxy(address(impl), abi.encodeCall(DIDRegistry.initialize, (address(0))));
    }

    function testCannotReinitialize() public {
        vm.expectRevert();
        registry.initialize(admin);
    }

    function testImplementationCannotBeInitialized() public {
        DIDRegistry impl = new DIDRegistry();
        vm.expectRevert();
        impl.initialize(admin);
    }

    function testRegisterDID() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        (address ctrl, bool active, uint256 regAt, uint256 updAt) = registry.resolveDID(did1);
        assertEq(ctrl, controller);
        assertTrue(active);
        assertEq(regAt, block.timestamp);
        assertEq(updAt, block.timestamp);
    }

    function testRegisterDIDEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit DIDRegistry.DIDRegistered(did1, controller, block.timestamp);

        vm.prank(registrar);
        registry.registerDID(did1, controller);
    }

    function testRegisterDIDRequiresRegistrarRole() public {
        vm.expectRevert();
        vm.prank(other);
        registry.registerDID(did1, controller);
    }

    function testRegisterDuplicateReverts() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyRegistered.selector, did1));
        vm.prank(registrar);
        registry.registerDID(did1, controller);
    }

    function testResolveUnregisteredReverts() public {
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, did1));
        registry.resolveDID(did1);
    }

    function testDeactivateDID() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.prank(controller);
        registry.deactivateDID(did1);

        (, bool active,,) = registry.resolveDID(did1);
        assertFalse(active);
    }

    function testDeactivateDIDEmitsEvent() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectEmit(true, false, false, true);
        emit DIDRegistry.DIDDeactivated(did1, block.timestamp);

        vm.prank(controller);
        registry.deactivateDID(did1);
    }

    function testDeactivateNotFoundReverts() public {
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, did1));
        vm.prank(controller);
        registry.deactivateDID(did1);
    }

    function testDeactivateNotControllerReverts() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, did1, other));
        vm.prank(other);
        registry.deactivateDID(did1);
    }

    function testDeactivateAlreadyDeactivatedReverts() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.prank(controller);
        registry.deactivateDID(did1);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyDeactivated.selector, did1));
        vm.prank(controller);
        registry.deactivateDID(did1);
    }

    function testUpdateController() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.prank(controller);
        registry.updateController(did1, newCtrl);

        (address ctrl,,, uint256 updAt) = registry.resolveDID(did1);
        assertEq(ctrl, newCtrl);
        assertEq(updAt, block.timestamp);
    }

    function testUpdateControllerEmitsEvent() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectEmit(true, true, true, false);
        emit DIDRegistry.DIDControllerUpdated(did1, controller, newCtrl);

        vm.prank(controller);
        registry.updateController(did1, newCtrl);
    }

    function testUpdateControllerNotFoundReverts() public {
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, did1));
        vm.prank(controller);
        registry.updateController(did1, newCtrl);
    }

    function testUpdateControllerNotControllerReverts() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, did1, other));
        vm.prank(other);
        registry.updateController(did1, newCtrl);
    }

    function testNewControllerCanActAfterUpdate() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.prank(controller);
        registry.updateController(did1, newCtrl);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, did1, controller));
        vm.prank(controller);
        registry.deactivateDID(did1);

        vm.prank(newCtrl);
        registry.deactivateDID(did1);

        (, bool active,,) = registry.resolveDID(did1);
        assertFalse(active);
    }

    function testUpgradeRequiresUpgraderRole() public {
        DIDRegistry newImpl = new DIDRegistry();
        vm.expectRevert();
        vm.prank(other);
        registry.upgradeToAndCall(address(newImpl), "");
    }

    function testUpgradeWithUpgraderRole() public {
        DIDRegistry newImpl = new DIDRegistry();
        vm.prank(admin);
        registry.upgradeToAndCall(address(newImpl), "");
    }

    function testDeactivatedDIDCannotBeReRegistered() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.prank(controller);
        registry.deactivateDID(did1);

        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyRegistered.selector, did1));
        vm.prank(registrar);
        registry.registerDID(did1, controller);
    }

    // ---------------------------------------------------------------
    // lastUpdatedAt
    // ---------------------------------------------------------------

    function testLastUpdatedAtOnRegister() public {
        assertEq(registry.lastUpdatedAt(), 0);

        vm.prank(registrar);
        registry.registerDID(did1, controller);

        assertEq(registry.lastUpdatedAt(), block.timestamp);
    }

    function testLastUpdatedAtOnDeactivate() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.warp(block.timestamp + 100);

        vm.prank(controller);
        registry.deactivateDID(did1);

        assertEq(registry.lastUpdatedAt(), block.timestamp);
    }

    function testLastUpdatedAtOnUpdateController() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.warp(block.timestamp + 200);

        vm.prank(controller);
        registry.updateController(did1, newCtrl);

        assertEq(registry.lastUpdatedAt(), block.timestamp);
    }

    // ---------------------------------------------------------------
    // DIDRegistryUpdated event
    // ---------------------------------------------------------------

    function testRegistryUpdatedEmittedOnRegister() public {
        vm.expectEmit(true, true, true, true);
        emit DIDRegistry.DIDRegistryUpdated(did1, 1, registrar, block.timestamp);

        vm.prank(registrar);
        registry.registerDID(did1, controller);
    }

    function testRegistryUpdatedEmittedOnDeactivate() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectEmit(true, true, true, true);
        emit DIDRegistry.DIDRegistryUpdated(did1, 2, controller, block.timestamp);

        vm.prank(controller);
        registry.deactivateDID(did1);
    }

    function testRegistryUpdatedEmittedOnUpdateController() public {
        vm.prank(registrar);
        registry.registerDID(did1, controller);

        vm.expectEmit(true, true, true, true);
        emit DIDRegistry.DIDRegistryUpdated(did1, 3, controller, block.timestamp);

        vm.prank(controller);
        registry.updateController(did1, newCtrl);
    }

    // ---------------------------------------------------------------
    // __UUPSUpgradeable_init (implicit — setUp succeeds via proxy)
    // ---------------------------------------------------------------

    function testInitializeWithUUPSInit() public view {
        // If __UUPSUpgradeable_init() failed, setUp proxy deployment would revert.
        // Verify proxy is functional by checking a role.
        assertTrue(registry.hasRole(registry.UPGRADER_ROLE(), admin));
    }
}
