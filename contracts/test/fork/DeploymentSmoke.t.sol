// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// @title DeploymentSmoke — Unified Sepolia deployment verification
/// @notice Fork test validating all 7 Sepolia contracts: existence, proxy→impl
///         wiring, cross-references, role configuration, and ERC-1967 slots.
contract DeploymentSmokeTest is Test {
    // ── ERC-1967 implementation slot ──
    bytes32 constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // ── Deployer / Admin ──
    address constant DEPLOYER = 0x3B50966A8B71f277e90e14cdC31455F6Af3977e6;

    // ── Sepolia proxies (from deployment-manifest.sepolia.json) ──
    address constant DID_PROXY = 0x6C6fA7f93860F16A1dFDD60Ca3B83b703C597a0A;
    address constant VCA_PROXY = 0x95D02Ae28D6fa86f67F121bA36d9cbD363AaFc68;
    address constant AV_PROXY  = 0xCE863E465f21Df87Ad9F0A2af838Fac1750F08d2;
    address constant CR_PROXY  = 0xaE4B71776Fab8E431ceE4874Ad3a2a97588D89FB;
    address constant TAV_PROXY = 0x2Ad7540B14585ebFB3c86604d1927b40e2eFa5db;
    address constant CCIP_RX_PROXY = 0x234Aec51d3977bA5174B068d2Daf15e5367C0bF0;
    address constant CCIP_TX_PROXY = 0xB8238cA59c7479e16d888A86A533A3113886A260;

    // ── Sepolia implementations (from manifest) ──
    address constant DID_IMPL = 0xDEecD6a976D5999315dcf0cf8E7Fa0e6ea887cD6;
    address constant VCA_IMPL = 0x3B7803BA081228Ea98626BE219755B0295267013;
    address constant AV_IMPL  = 0x2AE518D86774c814a73CA03464B355A3A228Ac8D;
    address constant CR_IMPL  = 0x94DE2311e67ABD4332c358B9c3a37E231f298249;
    address constant TAV_IMPL = 0x893aad8B32e77845B2485e033c7031E31c13Ec9b;
    address constant CCIP_RX_IMPL = 0x873A6c71eB179da1e6a53E4958435919CCb0940F;
    address constant CCIP_TX_IMPL = 0x30De5aDcD1Db72F93Ed4ceF92240b2A97D652969;

    // ── Role hashes ──
    bytes32 constant DEFAULT_ADMIN = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");
    bytes32 constant ANCHOR_WRITER_ROLE = keccak256("ANCHOR_WRITER_ROLE");
    bytes32 constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");
    bytes32 constant SIGNER_ADMIN_ROLE = keccak256("SIGNER_ADMIN_ROLE");

    // ── CCIP Router ──
    address constant CCIP_ROUTER = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;

    function setUp() public {
        string memory rpc = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpc);
        assertEq(block.chainid, 11155111, "Not Sepolia");
    }

    // ── 1. All proxies have bytecode ──
    function test_AllProxiesExist() public view {
        assertTrue(DID_PROXY.code.length > 0, "DIDRegistry proxy missing");
        assertTrue(VCA_PROXY.code.length > 0, "VCHashAnchors proxy missing");
        assertTrue(AV_PROXY.code.length > 0, "AttestationVerifier proxy missing");
        assertTrue(CR_PROXY.code.length > 0, "CredentialRegistry proxy missing");
        assertTrue(TAV_PROXY.code.length > 0, "TrustAttestationVerifier proxy missing");
        assertTrue(CCIP_RX_PROXY.code.length > 0, "TLHCCIPReceiver proxy missing");
        assertTrue(CCIP_TX_PROXY.code.length > 0, "TLHCCIPSender proxy missing");
    }

    // ── 2. All implementations have bytecode ──
    function test_AllImplementationsExist() public view {
        assertTrue(DID_IMPL.code.length > 0, "DIDRegistry impl missing");
        assertTrue(VCA_IMPL.code.length > 0, "VCHashAnchors impl missing");
        assertTrue(AV_IMPL.code.length > 0, "AttestationVerifier impl missing");
        assertTrue(CR_IMPL.code.length > 0, "CredentialRegistry impl missing");
        assertTrue(TAV_IMPL.code.length > 0, "TrustAttestationVerifier impl missing");
        assertTrue(CCIP_RX_IMPL.code.length > 0, "TLHCCIPReceiver impl missing");
        assertTrue(CCIP_TX_IMPL.code.length > 0, "TLHCCIPSender impl missing");
    }

    // ── 3. ERC-1967 slot → correct implementation ──
    function test_ProxyToImplSlots() public view {
        assertEq(_readImpl(DID_PROXY), DID_IMPL, "DIDRegistry impl slot mismatch");
        assertEq(_readImpl(VCA_PROXY), VCA_IMPL, "VCHashAnchors impl slot mismatch");
        assertEq(_readImpl(AV_PROXY), AV_IMPL, "AttestationVerifier impl slot mismatch");
        assertEq(_readImpl(CR_PROXY), CR_IMPL, "CredentialRegistry impl slot mismatch");
        assertEq(_readImpl(TAV_PROXY), TAV_IMPL, "TrustAttestationVerifier impl slot mismatch");
        assertEq(_readImpl(CCIP_RX_PROXY), CCIP_RX_IMPL, "TLHCCIPReceiver impl slot mismatch");
        assertEq(_readImpl(CCIP_TX_PROXY), CCIP_TX_IMPL, "TLHCCIPSender impl slot mismatch");
    }

    // ── 4. Cross-contract wiring ──
    function test_AttestationVerifierWiring() public view {
        // AV → DIDRegistry
        (bool ok1, bytes memory r1) = AV_PROXY.staticcall(abi.encodeWithSignature("didRegistry()"));
        assertTrue(ok1, "didRegistry() call failed");
        assertEq(abi.decode(r1, (address)), DID_PROXY, "AV.didRegistry mismatch");

        // AV → VCHashAnchors
        (bool ok2, bytes memory r2) = AV_PROXY.staticcall(abi.encodeWithSignature("vcHashAnchors()"));
        assertTrue(ok2, "vcHashAnchors() call failed");
        assertEq(abi.decode(r2, (address)), VCA_PROXY, "AV.vcHashAnchors mismatch");
    }

    function test_TrustAttestationVerifierWiring() public view {
        // TAV → CredentialRegistry
        (bool ok, bytes memory r) = TAV_PROXY.staticcall(abi.encodeWithSignature("credentialRegistry()"));
        assertTrue(ok, "credentialRegistry() call failed");
        assertEq(abi.decode(r, (address)), CR_PROXY, "TAV.credentialRegistry mismatch");
    }

    function test_CCIPReceiverWiring() public view {
        // Receiver → Router
        (bool ok, bytes memory r) = CCIP_RX_PROXY.staticcall(abi.encodeWithSignature("getRouter()"));
        assertTrue(ok, "getRouter() call failed");
        assertEq(abi.decode(r, (address)), CCIP_ROUTER, "Receiver.getRouter mismatch");
    }

    // ── 5. DEFAULT_ADMIN_ROLE on all contracts ──
    function test_DeployerHasAdminOnAll() public view {
        _assertRole(DID_PROXY, DEFAULT_ADMIN, DEPLOYER, "DIDRegistry");
        _assertRole(VCA_PROXY, DEFAULT_ADMIN, DEPLOYER, "VCHashAnchors");
        _assertRole(AV_PROXY, DEFAULT_ADMIN, DEPLOYER, "AttestationVerifier");
        _assertRole(CR_PROXY, DEFAULT_ADMIN, DEPLOYER, "CredentialRegistry");
        _assertRole(TAV_PROXY, DEFAULT_ADMIN, DEPLOYER, "TrustAttestationVerifier");
        _assertRole(CCIP_RX_PROXY, DEFAULT_ADMIN, DEPLOYER, "TLHCCIPReceiver");
        _assertRole(CCIP_TX_PROXY, DEFAULT_ADMIN, DEPLOYER, "TLHCCIPSender");
    }

    // ── 6. UPGRADER_ROLE on all contracts ──
    function test_DeployerHasUpgraderOnAll() public view {
        _assertRole(DID_PROXY, UPGRADER_ROLE, DEPLOYER, "DIDRegistry");
        _assertRole(VCA_PROXY, UPGRADER_ROLE, DEPLOYER, "VCHashAnchors");
        _assertRole(AV_PROXY, UPGRADER_ROLE, DEPLOYER, "AttestationVerifier");
        _assertRole(CR_PROXY, UPGRADER_ROLE, DEPLOYER, "CredentialRegistry");
        _assertRole(TAV_PROXY, UPGRADER_ROLE, DEPLOYER, "TrustAttestationVerifier");
        _assertRole(CCIP_RX_PROXY, UPGRADER_ROLE, DEPLOYER, "TLHCCIPReceiver");
        _assertRole(CCIP_TX_PROXY, UPGRADER_ROLE, DEPLOYER, "TLHCCIPSender");
    }

    // ── 7. Operational roles ──
    function test_OperationalRoles() public view {
        // REGISTRAR_ROLE on DIDRegistry
        _assertRole(DID_PROXY, REGISTRAR_ROLE, DEPLOYER, "DIDRegistry.REGISTRAR");

        // ANCHOR_WRITER_ROLE on VCHashAnchors
        _assertRole(VCA_PROXY, ANCHOR_WRITER_ROLE, DEPLOYER, "VCA.ANCHOR_WRITER");

        // SIGNER_ADMIN_ROLE on AttestationVerifier (deployer should have it)
        _assertRole(AV_PROXY, SIGNER_ADMIN_ROLE, DEPLOYER, "AV.SIGNER_ADMIN");

        // VERIFIER_ROLE on CredentialRegistry for CCIP Receiver
        _assertRole(CR_PROXY, VERIFIER_ROLE, CCIP_RX_PROXY, "CR.VERIFIER for Receiver");
    }

    // ── Helpers ──
    function _readImpl(address proxy) internal view returns (address) {
        bytes32 raw = vm.load(proxy, IMPL_SLOT);
        return address(uint160(uint256(raw)));
    }

    function _assertRole(address proxy, bytes32 role, address account, string memory label) internal view {
        (bool ok, bytes memory r) = proxy.staticcall(
            abi.encodeWithSignature("hasRole(bytes32,address)", role, account)
        );
        assertTrue(ok, string.concat(label, ": hasRole call failed"));
        assertTrue(abi.decode(r, (bool)), string.concat(label, ": role missing"));
    }
}
