pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IAccessControlMinimal {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IAttestationVerifierWiring {
    function didRegistry() external view returns (address);
    function vcHashAnchors() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
}

contract AttestationVerifierForkTest is Test {
    // ---- Sepolia deployed proxies ----
    address constant AV_PROXY   = 0xCE863E465f21Df87Ad9F0A2af838Fac1750F08d2;
    address constant AV_IMPL    = 0x2AE518D86774c814a73CA03464B355A3A228Ac8D;
    address constant DID_PROXY  = 0x6C6fA7f93860F16A1dFDD60Ca3B83b703C597a0A;
    address constant VCA_PROXY  = 0x95D02Ae28D6fa86f67F121bA36d9cbD363AaFc68;

    // ---- Known deployer/admin (your live state) ----
    address constant DEPLOYER   = 0x3B50966A8B71f277e90e14cdC31455F6Af3977e6;

    // ---- UUPS UUID (your authoritative value) ----
    bytes32 constant UUPS_UUID =
        bytes32(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);

    IAttestationVerifierWiring av = IAttestationVerifierWiring(AV_PROXY);
    IAttestationVerifierWiring avImpl = IAttestationVerifierWiring(AV_IMPL);
    IAccessControlMinimal ac = IAccessControlMinimal(AV_PROXY);

    function setUp() public {
        string memory rpc = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpc);
        assertEq(block.chainid, 11155111);
    }

    function test_uups_uuid_is_correct() public view {
        bytes32 uuid = avImpl.proxiableUUID();
        assertEq(uuid, UUPS_UUID, "proxiableUUID mismatch");
    }

    function test_wiring_didRegistry_and_vcHashAnchors() public view {
        assertEq(av.didRegistry(), DID_PROXY, "didRegistry wiring mismatch");
        assertEq(av.vcHashAnchors(), VCA_PROXY, "vcHashAnchors wiring mismatch");
    }

    function test_deployer_has_default_admin_role() public view {
        bytes32 admin = ac.DEFAULT_ADMIN_ROLE();
        assertTrue(ac.hasRole(admin, DEPLOYER), "deployer missing DEFAULT_ADMIN_ROLE");
    }
}


