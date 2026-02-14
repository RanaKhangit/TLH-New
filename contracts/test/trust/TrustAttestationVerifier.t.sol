// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {TrustAttestationVerifier} from "../../src/trust/TrustAttestationVerifier.sol";
import {CredentialRegistry} from "../../src/trust/CredentialRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TrustAttestationVerifierTest is Test {
    using MessageHashUtils for bytes32;

    TrustAttestationVerifier internal verifier;
    CredentialRegistry internal registry;

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

        // Deploy CredentialRegistry via proxy
        CredentialRegistry regImpl = new CredentialRegistry();
        ERC1967Proxy regProxy =
            new ERC1967Proxy(address(regImpl), abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin));
        registry = CredentialRegistry(address(regProxy));

        // Deploy TrustAttestationVerifier via proxy
        TrustAttestationVerifier verImpl = new TrustAttestationVerifier();
        ERC1967Proxy verProxy = new ERC1967Proxy(
            address(verImpl),
            abi.encodeWithSelector(TrustAttestationVerifier.initialize.selector, admin, address(registry))
        );
        verifier = TrustAttestationVerifier(address(verProxy));

        // Grant VERIFIER_ROLE on CredentialRegistry to the verifier proxy
        vm.startPrank(admin);
        registry.grantVerifier(address(verifier));
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
        TrustAttestationVerifier impl = new TrustAttestationVerifier();
        vm.expectRevert();
        impl.initialize(admin, address(registry));
    }

    // ---- positive attestation: writeCredential called + event emitted ----

    function testPositiveAttestationWritesCredential() public {
        bytes32 attId = keccak256("att-pos");
        bytes32 did = keccak256("did:tlh:clinician-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicate(true, block.timestamp, expiresAt);
        bytes memory sig = _sign(attId, did, predicate);

        // Expect CredentialWrittenViaAttestation event
        vm.expectEmit(true, true, true, true);
        emit TrustAttestationVerifier.CredentialWrittenViaAttestation(did, PRED_TYPE, attId);

        verifier.submitAttestation(attId, did, predicate, sig);

        // Verify credential was written to registry
        assertTrue(registry.isCredentialValid(did, PRED_TYPE));
    }

    // ---- negative attestation: writeCredential NOT called + NO event ----

    function testNegativeAttestationDoesNotWriteCredential() public {
        bytes32 attId = keccak256("att-neg");
        bytes32 did = keccak256("did:tlh:clinician-2");
        bytes memory predicate = _buildPredicate(false, block.timestamp, block.timestamp + 365 days);
        bytes memory sig = _sign(attId, did, predicate);

        // Record logs to verify NO CredentialWrittenViaAttestation event
        vm.recordLogs();

        verifier.submitAttestation(attId, did, predicate, sig);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Only AttestationSubmitted from base should be emitted, NOT CredentialWrittenViaAttestation
        bytes32 credWrittenSig = keccak256("CredentialWrittenViaAttestation(bytes32,bytes32,bytes32)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(logs[i].topics[0] != credWrittenSig, "CredentialWrittenViaAttestation should NOT be emitted");
        }

        // Verify no credential was written
        assertFalse(registry.isCredentialValid(did, PRED_TYPE));
    }

    // ---- attestation stored regardless of result ----

    function testAttestationStoredForBothResults() public {
        // Positive
        bytes32 attIdPos = keccak256("att-store-pos");
        bytes32 did = keccak256("did:tlh:clinician-3");
        bytes memory predPos = _buildPredicate(true, block.timestamp, block.timestamp + 365 days);
        bytes memory sigPos = _sign(attIdPos, did, predPos);
        verifier.submitAttestation(attIdPos, did, predPos, sigPos);

        (bool exists1,,, bool result1,) = verifier.verifyAttestation(attIdPos);
        assertTrue(exists1);
        assertTrue(result1);

        // Negative (different attestation ID)
        bytes32 attIdNeg = keccak256("att-store-neg");
        bytes32 did2 = keccak256("did:tlh:clinician-4");
        bytes memory predNeg = _buildPredicate(false, block.timestamp, block.timestamp + 365 days);
        bytes memory sigNeg = _sign(attIdNeg, did2, predNeg);
        verifier.submitAttestation(attIdNeg, did2, predNeg, sigNeg);

        (bool exists2,,, bool result2,) = verifier.verifyAttestation(attIdNeg);
        assertTrue(exists2);
        assertFalse(result2);
    }

    // ---- verifyAttestation returns empty for unknown ----

    function testVerifyAttestationNotFound() public view {
        (bool exists,,,,) = verifier.verifyAttestation(keccak256("unknown"));
        assertFalse(exists);
    }

    // ---- setCredentialRegistry admin only ----

    function testSetCredentialRegistryAdminOnly() public {
        vm.prank(stranger);
        vm.expectRevert();
        verifier.setCredentialRegistry(address(0x1234));

        vm.prank(admin);
        verifier.setCredentialRegistry(address(0x1234));
        assertEq(address(verifier.credentialRegistry()), address(0x1234));
    }

    // ---- upgrade authorization ----

    function testUpgradeOnlyUpgrader() public {
        TrustAttestationVerifier newImpl = new TrustAttestationVerifier();

        // Stranger cannot upgrade
        vm.prank(stranger);
        vm.expectRevert();
        verifier.upgradeToAndCall(address(newImpl), "");

        // Admin (who has UPGRADER_ROLE) can upgrade
        vm.prank(admin);
        verifier.upgradeToAndCall(address(newImpl), "");
    }
}
