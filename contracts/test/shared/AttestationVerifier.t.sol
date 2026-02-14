// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AttestationVerifier} from "../../src/shared/AttestationVerifier.sol";
import {DIDRegistry} from "../../src/shared/DIDRegistry.sol";
import {VCHashAnchors} from "../../src/shared/VCHashAnchors.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract AttestationVerifierTest is Test {
    using MessageHashUtils for bytes32;

    AttestationVerifier internal verifier;
    DIDRegistry internal didRegistry;
    VCHashAnchors internal vcAnchors;

    address internal admin = address(0xA1);
    address internal stranger = address(0xA3);

    uint256 internal signerSk;
    address internal signer;

    bytes32 internal constant PRED_TYPE = keccak256("GMC_REGISTERED");
    bytes32 internal constant VC_TYPE = keccak256("GMC_LICENSE");
    bytes32 internal constant CONTENT_HASH = keccak256("content");

    function setUp() public {
        vm.warp(1_700_000_000);

        signerSk = 0xBEEF;
        signer = vm.addr(signerSk);

        // Deploy DIDRegistry via proxy
        DIDRegistry didImpl = new DIDRegistry();
        ERC1967Proxy didProxy =
            new ERC1967Proxy(address(didImpl), abi.encodeWithSelector(DIDRegistry.initialize.selector, admin));
        didRegistry = DIDRegistry(address(didProxy));

        // Deploy VCHashAnchors via proxy
        VCHashAnchors vcImpl = new VCHashAnchors();
        ERC1967Proxy vcProxy =
            new ERC1967Proxy(address(vcImpl), abi.encodeWithSelector(VCHashAnchors.initialize.selector, admin));
        vcAnchors = VCHashAnchors(address(vcProxy));

        // Deploy AttestationVerifier via proxy
        AttestationVerifier avImpl = new AttestationVerifier();
        ERC1967Proxy avProxy = new ERC1967Proxy(
            address(avImpl),
            abi.encodeWithSelector(
                AttestationVerifier.initialize.selector, admin, address(didRegistry), address(vcAnchors)
            )
        );
        verifier = AttestationVerifier(address(avProxy));

        // Grant roles: verifier needs REGISTRAR_ROLE on DIDRegistry + ANCHOR_WRITER_ROLE on VCHashAnchors
        vm.startPrank(admin);
        didRegistry.grantRole(didRegistry.REGISTRAR_ROLE(), address(verifier));
        vcAnchors.grantRole(vcAnchors.ANCHOR_WRITER_ROLE(), address(verifier));
        verifier.addSigner(signer);
        vm.stopPrank();
    }

    // ---- helpers ----

    function _buildPredicate(bool result, uint256 checkedAt, uint256 expiresAt) internal pure returns (bytes memory) {
        bytes memory encoded = abi.encode(PRED_TYPE, result, checkedAt, expiresAt, VC_TYPE, CONTENT_HASH, bytes(""));
        return abi.encodePacked(result ? bytes1(0x01) : bytes1(0x00), encoded);
    }

    function _sign(bytes32 attestationId, bytes32 subjectDID, bytes memory predicateData)
        internal
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
                abi.encodePacked(
                    "TLH_ATTESTATION_V1",
                    block.chainid,
                    address(verifier),
                    attestationId,
                    subjectDID,
                    keccak256(predicateData)
                )
            ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ---- initialization ----

    function testImplCannotBeReinitialized() public {
        AttestationVerifier impl = new AttestationVerifier();
        vm.expectRevert();
        impl.initialize(admin, address(didRegistry), address(vcAnchors));
    }

    function testProxyCannotBeReinitialized() public {
        vm.expectRevert();
        verifier.initialize(admin, address(didRegistry), address(vcAnchors));
    }

    function testProxyInitializesRolesCorrectly() public view {
        assertTrue(verifier.hasRole(verifier.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(verifier.hasRole(verifier.ADMIN_ROLE(), admin));
        assertTrue(verifier.hasRole(verifier.UPGRADER_ROLE(), admin));
        assertTrue(verifier.hasRole(verifier.SIGNER_ADMIN_ROLE(), admin));
    }

    // ---- positive attestation: DID + VC hash + status event ----

    function testPositiveAttestationWritesDIDAndVCHash() public {
        bytes32 attId = keccak256("att-pos");
        bytes32 did = keccak256("did:tlh:clinician-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicate(true, block.timestamp, expiresAt);
        bytes memory sig = _sign(attId, did, predicate);

        verifier.submitAttestation(attId, did, predicate, sig);

        // Verify DID was registered
        (address controller, bool active,,) = didRegistry.resolveDID(did);
        assertEq(controller, address(verifier));
        assertTrue(active);

        // Verify VC hash was anchored
        (bytes32 hash, uint256 anchoredAt, bool revoked) = vcAnchors.getAnchor(did, VC_TYPE);
        assertEq(hash, CONTENT_HASH);
        assertEq(anchoredAt, block.timestamp);
        assertFalse(revoked);
    }

    // ---- attestation stored ----

    function testAttestationStoredAndVerifiable() public {
        bytes32 attId = keccak256("att-store");
        bytes32 did = keccak256("did:tlh:clinician-2");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 365 days);
        bytes memory sig = _sign(attId, did, predicate);

        verifier.submitAttestation(attId, did, predicate, sig);

        (bool exists,,, bool result,) = verifier.verifyAttestation(attId);
        assertTrue(exists);
        assertTrue(result);
    }

    // ---- verifyAttestation returns empty for unknown ----

    function testVerifyAttestationNotFound() public view {
        (bool exists,,,,) = verifier.verifyAttestation(keccak256("unknown"));
        assertFalse(exists);
    }

    // ---- F-01: negative attestation does NOT trigger side-effects ----

    function testNegativeAttestationDoesNotRegisterDIDOrAnchorHash() public {
        bytes32 attId = keccak256("att-neg");
        bytes32 did = keccak256("did:tlh:clinician-neg");
        bytes memory predicate = _buildPredicate(false, block.timestamp, block.timestamp + 365 days);
        bytes memory sig = _sign(attId, did, predicate);

        // Record logs to verify no shared-anchor events
        vm.recordLogs();
        verifier.submitAttestation(attId, did, predicate, sig);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Only AttestationSubmitted should be emitted — NOT DID/VC/Status events
        bytes32 didRegSig = keccak256("DIDRegisteredViaAttestation(bytes32,bytes32)");
        bytes32 vcAnchorSig = keccak256("VCHashAnchoredViaAttestation(bytes32,bytes32,bytes32,bytes32)");
        bytes32 credStatusSig = keccak256("CredentialStatusUpdated(bytes32,bytes32,bool,bytes32,uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(logs[i].topics[0] != didRegSig, "DIDRegisteredViaAttestation should NOT be emitted");
            assertTrue(logs[i].topics[0] != vcAnchorSig, "VCHashAnchoredViaAttestation should NOT be emitted");
            assertTrue(logs[i].topics[0] != credStatusSig, "CredentialStatusUpdated should NOT be emitted");
        }

        // DID should NOT be registered
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, did));
        didRegistry.resolveDID(did);

        // Attestation itself IS stored (base behavior)
        (bool exists,,, bool result,) = verifier.verifyAttestation(attId);
        assertTrue(exists);
        assertFalse(result);
    }

    // ---- F-03: narrowed try/catch only swallows DIDAlreadyRegistered ----

    function testPositiveAttestationDuplicateDIDProceeds() public {
        bytes32 did = keccak256("did:tlh:clinician-dup");

        // Pre-register the DID so the try/catch fires
        vm.prank(admin);
        didRegistry.registerDID(did, admin);

        bytes32 attId = keccak256("att-dup-did");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 365 days);
        bytes memory sig = _sign(attId, did, predicate);

        // Should succeed — DIDAlreadyRegistered is swallowed
        verifier.submitAttestation(attId, did, predicate, sig);

        // VC hash should still be anchored
        (bytes32 hash,,) = vcAnchors.getAnchor(did, VC_TYPE);
        assertEq(hash, CONTENT_HASH);
    }

    // ---- upgrade authorization ----

    function testUpgradeOnlyUpgrader() public {
        AttestationVerifier newImpl = new AttestationVerifier();

        // Stranger cannot upgrade
        vm.prank(stranger);
        vm.expectRevert();
        verifier.upgradeToAndCall(address(newImpl), "");

        // Admin (UPGRADER_ROLE) can upgrade
        vm.prank(admin);
        verifier.upgradeToAndCall(address(newImpl), "");
    }
}
