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

    // ---- explicit per-action events via vm.recordLogs ----

    function testRegisterDIDEmitsBothEvents() public {
        vm.warp(1_700_000_500);
        vm.prank(admin);
        vm.recordLogs();
        registry.registerDID(DID1, address(0xBEEF));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // DIDRegistered(did, controller, timestamp)
        bytes32 regSig = keccak256("DIDRegistered(bytes32,address,uint256)");
        // DIDRegistryUpdated(did, action, actor, timestamp)
        bytes32 updSig = keccak256("DIDRegistryUpdated(bytes32,uint8,address,uint256)");

        bool foundReg;
        bool foundUpd;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == regSig) {
                assertEq(logs[i].topics[1], DID1);
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(address(0xBEEF)))));
                foundReg = true;
            }
            if (logs[i].topics[0] == updSig) {
                assertEq(logs[i].topics[1], DID1);
                assertEq(logs[i].topics[2], bytes32(uint256(1))); // action=1
                assertEq(logs[i].topics[3], bytes32(uint256(uint160(admin)))); // actor=admin
                uint256 ts = abi.decode(logs[i].data, (uint256));
                assertEq(ts, 1_700_000_500);
                foundUpd = true;
            }
        }
        assertTrue(foundReg, "DIDRegistered not emitted");
        assertTrue(foundUpd, "DIDRegistryUpdated not emitted");
    }

    function testDeactivateDIDEmitsBothEvents() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_600);
        vm.prank(address(0xBEEF));
        vm.recordLogs();
        registry.deactivateDID(DID1);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 deactSig = keccak256("DIDDeactivated(bytes32,uint256)");
        bytes32 updSig = keccak256("DIDRegistryUpdated(bytes32,uint8,address,uint256)");

        bool foundDeact;
        bool foundUpd;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == deactSig) {
                assertEq(logs[i].topics[1], DID1);
                foundDeact = true;
            }
            if (logs[i].topics[0] == updSig) {
                assertEq(logs[i].topics[1], DID1);
                assertEq(logs[i].topics[2], bytes32(uint256(2))); // action=2
                assertEq(logs[i].topics[3], bytes32(uint256(uint160(address(0xBEEF))))); // actor=controller
                foundUpd = true;
            }
        }
        assertTrue(foundDeact, "DIDDeactivated not emitted");
        assertTrue(foundUpd, "DIDRegistryUpdated not emitted");
    }

    function testUpdateControllerEmitsBothEvents() public {
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_700);
        vm.prank(address(0xBEEF));
        vm.recordLogs();
        registry.updateController(DID1, address(0xCAFE));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 ctrlSig = keccak256("DIDControllerUpdated(bytes32,address,address)");
        bytes32 updSig = keccak256("DIDRegistryUpdated(bytes32,uint8,address,uint256)");

        bool foundCtrl;
        bool foundUpd;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ctrlSig) {
                assertEq(logs[i].topics[1], DID1);
                assertEq(logs[i].topics[2], bytes32(uint256(uint160(address(0xBEEF))))); // old
                assertEq(logs[i].topics[3], bytes32(uint256(uint160(address(0xCAFE))))); // new
                foundCtrl = true;
            }
            if (logs[i].topics[0] == updSig) {
                assertEq(logs[i].topics[1], DID1);
                assertEq(logs[i].topics[2], bytes32(uint256(3))); // action=3
                assertEq(logs[i].topics[3], bytes32(uint256(uint160(address(0xBEEF))))); // actor=old controller
                foundUpd = true;
            }
        }
        assertTrue(foundCtrl, "DIDControllerUpdated not emitted");
        assertTrue(foundUpd, "DIDRegistryUpdated not emitted");
    }

    // ---- lastUpdatedAt MUST NOT change on revert paths ----

    function testLastUpdatedAtUnchangedOnStrangerRegisterRevert() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));
        uint256 tsAfterFirst = registry.lastUpdatedAt();

        vm.warp(1_700_000_999);
        vm.prank(stranger);
        vm.expectRevert(); // AccessControl revert
        registry.registerDID(DID2, address(0xCAFE));

        assertEq(registry.lastUpdatedAt(), tsAfterFirst);
    }

    function testLastUpdatedAtUnchangedOnDuplicateRegisterRevert() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));
        uint256 tsAfterFirst = registry.lastUpdatedAt();
        assertEq(tsAfterFirst, 1_700_000_100);

        vm.warp(1_700_000_999);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyRegistered.selector, DID1));
        registry.registerDID(DID1, address(0xBEEF));

        // lastUpdatedAt must NOT have changed
        assertEq(registry.lastUpdatedAt(), tsAfterFirst);
    }

    function testLastUpdatedAtUnchangedOnNotControllerDeactivateRevert() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));
        uint256 tsAfterReg = registry.lastUpdatedAt();

        vm.warp(1_700_000_999);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, DID1, stranger));
        registry.deactivateDID(DID1);

        assertEq(registry.lastUpdatedAt(), tsAfterReg);
    }

    function testLastUpdatedAtUnchangedOnAlreadyDeactivatedRevert() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_200);
        vm.prank(address(0xBEEF));
        registry.deactivateDID(DID1);
        uint256 tsAfterDeact = registry.lastUpdatedAt();
        assertEq(tsAfterDeact, 1_700_000_200);

        vm.warp(1_700_000_999);
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDAlreadyDeactivated.selector, DID1));
        registry.deactivateDID(DID1);

        assertEq(registry.lastUpdatedAt(), tsAfterDeact);
    }

    function testLastUpdatedAtUnchangedOnNotControllerUpdateRevert() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));
        uint256 tsAfterReg = registry.lastUpdatedAt();

        vm.warp(1_700_000_999);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.NotDIDController.selector, DID1, stranger));
        registry.updateController(DID1, address(0xCAFE));

        assertEq(registry.lastUpdatedAt(), tsAfterReg);
    }

    // ---- read-path correctness after mutations ----

    function testResolveDIDFullStateAfterDeactivate() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_200);
        vm.prank(address(0xBEEF));
        registry.deactivateDID(DID1);

        (address controller, bool active, uint256 registeredAt, uint256 updatedAt) = registry.resolveDID(DID1);
        assertEq(controller, address(0xBEEF)); // controller preserved
        assertFalse(active); // deactivated
        assertEq(registeredAt, 1_700_000_100); // unchanged
        assertEq(updatedAt, 1_700_000_200); // updated to deactivation time
    }

    function testResolveDIDFullStateAfterUpdateController() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_200);
        vm.prank(address(0xBEEF));
        registry.updateController(DID1, address(0xCAFE));

        (address controller, bool active, uint256 registeredAt, uint256 updatedAt) = registry.resolveDID(DID1);
        assertEq(controller, address(0xCAFE)); // new controller
        assertTrue(active); // still active
        assertEq(registeredAt, 1_700_000_100); // unchanged
        assertEq(updatedAt, 1_700_000_200); // updated to mutation time
    }

    function testMultipleDIDsIndependentState() public {
        vm.warp(1_700_000_100);
        vm.prank(admin);
        registry.registerDID(DID1, address(0xBEEF));

        vm.warp(1_700_000_200);
        vm.prank(admin);
        registry.registerDID(DID2, address(0xCAFE));

        // Deactivate DID1 — DID2 must remain active and unchanged
        vm.warp(1_700_000_300);
        vm.prank(address(0xBEEF));
        registry.deactivateDID(DID1);

        (address c1, bool a1, uint256 r1, uint256 u1) = registry.resolveDID(DID1);
        assertEq(c1, address(0xBEEF));
        assertFalse(a1);
        assertEq(r1, 1_700_000_100);
        assertEq(u1, 1_700_000_300);

        (address c2, bool a2, uint256 r2, uint256 u2) = registry.resolveDID(DID2);
        assertEq(c2, address(0xCAFE));
        assertTrue(a2); // DID2 unaffected
        assertEq(r2, 1_700_000_200);
        assertEq(u2, 1_700_000_200); // unchanged
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
