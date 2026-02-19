// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {DIDRegistry} from "../../src/shared/DIDRegistry.sol";
import {VCHashAnchors} from "../../src/shared/VCHashAnchors.sol";
import {AttestationVerifier} from "../../src/shared/AttestationVerifier.sol";
import {CredentialRegistry} from "../../src/trust/CredentialRegistry.sol";
import {TrustAttestationVerifier} from "../../src/trust/TrustAttestationVerifier.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title E2ELifecycleTest — Full dual-chain lifecycle in a single local test
/// @notice Deploys all 5 core contracts (3 shared + 2 trust), wires roles,
///         then exercises: registerDID → anchorHash → submitAttestation(shared)
///         → submitAttestation(trust) → credential readback → revocation.
contract E2ELifecycleTest is Test {
    using MessageHashUtils for bytes32;

    // ── Shared chain contracts ──
    DIDRegistry internal didRegistry;
    VCHashAnchors internal vcAnchors;
    AttestationVerifier internal sharedVerifier;

    // ── Trust chain contracts ──
    CredentialRegistry internal credRegistry;
    TrustAttestationVerifier internal trustVerifier;

    // ── Actors ──
    address internal admin = address(0xA1);
    uint256 internal signerSk;
    address internal signer;

    // ── Constants ──
    bytes32 internal constant PRED_TYPE = keccak256("GMC_REGISTERED");
    bytes32 internal constant VC_TYPE = keccak256("GMC_LICENSE");
    bytes32 internal constant CONTENT_HASH = keccak256("content-hash-abc");
    bytes32 internal constant SUBJECT_DID = keccak256("did:tlh:clinician-e2e");
    bytes32 internal constant ATTESTATION_ID = keccak256("e2e-attestation-001");

    function setUp() public {
        vm.warp(1_700_000_000);

        signerSk = 0xBEEF;
        signer = vm.addr(signerSk);

        // ── Deploy shared chain contracts ──
        DIDRegistry didImpl = new DIDRegistry();
        ERC1967Proxy didProxy = new ERC1967Proxy(
            address(didImpl), abi.encodeWithSelector(DIDRegistry.initialize.selector, admin)
        );
        didRegistry = DIDRegistry(address(didProxy));

        VCHashAnchors vcImpl = new VCHashAnchors();
        ERC1967Proxy vcProxy = new ERC1967Proxy(
            address(vcImpl), abi.encodeWithSelector(VCHashAnchors.initialize.selector, admin)
        );
        vcAnchors = VCHashAnchors(address(vcProxy));

        AttestationVerifier avImpl = new AttestationVerifier();
        ERC1967Proxy avProxy = new ERC1967Proxy(
            address(avImpl),
            abi.encodeWithSelector(
                AttestationVerifier.initialize.selector, admin, address(didRegistry), address(vcAnchors)
            )
        );
        sharedVerifier = AttestationVerifier(address(avProxy));

        // ── Deploy trust chain contracts ──
        CredentialRegistry crImpl = new CredentialRegistry();
        ERC1967Proxy crProxy = new ERC1967Proxy(
            address(crImpl), abi.encodeWithSelector(CredentialRegistry.initialize.selector, admin)
        );
        credRegistry = CredentialRegistry(address(crProxy));

        TrustAttestationVerifier tavImpl = new TrustAttestationVerifier();
        ERC1967Proxy tavProxy = new ERC1967Proxy(
            address(tavImpl),
            abi.encodeWithSelector(TrustAttestationVerifier.initialize.selector, admin, address(credRegistry))
        );
        trustVerifier = TrustAttestationVerifier(address(tavProxy));

        // ── Wire cross-contract roles ──
        vm.startPrank(admin);
        // Shared verifier needs REGISTRAR + ANCHOR_WRITER on shared contracts
        didRegistry.grantRole(didRegistry.REGISTRAR_ROLE(), address(sharedVerifier));
        vcAnchors.grantRole(vcAnchors.ANCHOR_WRITER_ROLE(), address(sharedVerifier));
        // Trust verifier needs VERIFIER_ROLE on CredentialRegistry
        credRegistry.grantVerifier(address(trustVerifier));
        // Both verifiers need the same signer
        sharedVerifier.addSigner(signer);
        trustVerifier.addSigner(signer);
        vm.stopPrank();
    }

    // ── Helpers ──

    function _buildPredicate(bool result, uint256 checkedAt, uint256 expiresAt) internal pure returns (bytes memory) {
        bytes memory encoded = abi.encode(PRED_TYPE, result, checkedAt, expiresAt, VC_TYPE, CONTENT_HASH, bytes(""));
        return abi.encodePacked(result ? bytes1(0x01) : bytes1(0x00), encoded);
    }

    function _signShared(bytes32 attestationId, bytes32 subjectDID, bytes memory predicateData)
        internal
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "TLH_ATTESTATION_V1", block.chainid, address(sharedVerifier), attestationId, subjectDID, keccak256(predicateData)
            )
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        return abi.encodePacked(r, s, v);
    }

    function _signTrust(bytes32 attestationId, bytes32 subjectDID, bytes memory predicateData)
        internal
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "TLH_ATTESTATION_V1", block.chainid, address(trustVerifier), attestationId, subjectDID, keccak256(predicateData)
            )
        ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 1: Full happy-path lifecycle across all 5 contracts
    // ═══════════════════════════════════════════════════════════════════

    function test_E2E_FullLifecycle() public {
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicate(true, block.timestamp, expiresAt);

        // ── Step 1: Submit attestation to SHARED chain verifier ──
        bytes memory sharedSig = _signShared(ATTESTATION_ID, SUBJECT_DID, predicate);
        sharedVerifier.submitAttestation(ATTESTATION_ID, SUBJECT_DID, predicate, sharedSig);

        // ── Step 2: Verify DID was auto-registered ──
        (address controller, bool active, uint256 registeredAt,) = didRegistry.resolveDID(SUBJECT_DID);
        assertEq(controller, address(sharedVerifier), "DID controller should be shared verifier");
        assertTrue(active, "DID should be active");
        assertEq(registeredAt, block.timestamp, "DID registered at current timestamp");

        // ── Step 3: Verify VC hash was anchored ──
        (bytes32 hash, uint256 anchoredAt, bool revoked) = vcAnchors.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(hash, CONTENT_HASH, "VC content hash mismatch");
        assertEq(anchoredAt, block.timestamp, "Anchor timestamp mismatch");
        assertFalse(revoked, "Anchor should not be revoked");

        // ── Step 4: Verify shared attestation stored ──
        (bool exists, bytes32 storedDID,, bool result, uint256 timestamp) =
            sharedVerifier.verifyAttestation(ATTESTATION_ID);
        assertTrue(exists, "Shared attestation should exist");
        assertEq(storedDID, SUBJECT_DID, "Stored DID mismatch");
        assertTrue(result, "Attestation result should be true");
        assertEq(timestamp, block.timestamp, "Attestation timestamp mismatch");

        // ── Step 5: Submit same attestation to TRUST chain verifier ──
        // (In production, the EA submits to both chains with separate sigs)
        bytes32 trustAttId = keccak256("e2e-attestation-001-trust");
        bytes memory trustSig = _signTrust(trustAttId, SUBJECT_DID, predicate);
        trustVerifier.submitAttestation(trustAttId, SUBJECT_DID, predicate, trustSig);

        // ── Step 6: Verify credential was written to CredentialRegistry ──
        assertTrue(credRegistry.isCredentialValid(SUBJECT_DID, PRED_TYPE), "Credential should be valid");

        // ── Step 7: Verify trust attestation stored ──
        (bool texists, bytes32 tstoredDID,, bool tresult,) = trustVerifier.verifyAttestation(trustAttId);
        assertTrue(texists, "Trust attestation should exist");
        assertEq(tstoredDID, SUBJECT_DID, "Trust stored DID mismatch");
        assertTrue(tresult, "Trust attestation result should be true");

        // ── Step 8: Full readback — all 5 contracts have consistent state ──
        // DIDRegistry: DID exists & active
        (,bool stillActive,,) = didRegistry.resolveDID(SUBJECT_DID);
        assertTrue(stillActive);
        // VCHashAnchors: anchor exists
        (bytes32 h2,,) = vcAnchors.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(h2, CONTENT_HASH);
        // AttestationVerifier: attestation PASS
        (bool e2,,,bool r2,) = sharedVerifier.verifyAttestation(ATTESTATION_ID);
        assertTrue(e2 && r2);
        // CredentialRegistry: credential valid
        assertTrue(credRegistry.isCredentialValid(SUBJECT_DID, PRED_TYPE));
        // TrustAttestationVerifier: attestation PASS
        (bool e3,,,bool r3,) = trustVerifier.verifyAttestation(trustAttId);
        assertTrue(e3 && r3);
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 2: Negative attestation — no side effects on either chain
    // ═══════════════════════════════════════════════════════════════════

    function test_E2E_NegativeAttestationNoSideEffects() public {
        bytes32 negAttId = keccak256("e2e-neg-001");
        bytes32 negDID = keccak256("did:tlh:clinician-neg-e2e");
        bytes memory predicate = _buildPredicate(false, block.timestamp, block.timestamp + 365 days);

        // Submit to shared chain
        bytes memory sharedSig = _signShared(negAttId, negDID, predicate);
        sharedVerifier.submitAttestation(negAttId, negDID, predicate, sharedSig);

        // DID should NOT be registered
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, negDID));
        didRegistry.resolveDID(negDID);

        // Shared attestation IS stored but result=false
        (bool exists,,, bool result,) = sharedVerifier.verifyAttestation(negAttId);
        assertTrue(exists, "Negative attestation should be stored");
        assertFalse(result, "Result should be false");

        // Submit to trust chain
        bytes32 negTrustId = keccak256("e2e-neg-001-trust");
        bytes memory trustSig = _signTrust(negTrustId, negDID, predicate);
        trustVerifier.submitAttestation(negTrustId, negDID, predicate, trustSig);

        // Credential should NOT be valid
        assertFalse(credRegistry.isCredentialValid(negDID, PRED_TYPE), "Credential should not be valid after negative attestation");
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 3: Credential revocation after positive attestation
    // ═══════════════════════════════════════════════════════════════════

    function test_E2E_CredentialRevocation() public {
        bytes32 revAttId = keccak256("e2e-rev-001");
        bytes32 revDID = keccak256("did:tlh:clinician-rev-e2e");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 365 days);

        // Submit positive attestation to trust chain
        bytes memory sig = _signTrust(revAttId, revDID, predicate);
        trustVerifier.submitAttestation(revAttId, revDID, predicate, sig);

        // Credential should be valid
        assertTrue(credRegistry.isCredentialValid(revDID, PRED_TYPE), "Credential should be valid before revocation");

        // Admin revokes the credential
        vm.prank(admin);
        credRegistry.revokeCredential(revDID, PRED_TYPE);

        // Credential should now be invalid
        assertFalse(credRegistry.isCredentialValid(revDID, PRED_TYPE), "Credential should be invalid after revocation");
    }

    // ═══════════════════════════════════════════════════════════════════
    // TEST 4: DID deactivation after positive attestation
    // ═══════════════════════════════════════════════════════════════════

    function test_E2E_DIDDeactivation() public {
        bytes32 deactAttId = keccak256("e2e-deact-001");
        bytes32 deactDID = keccak256("did:tlh:clinician-deact-e2e");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 365 days);

        // Submit positive attestation to shared chain
        bytes memory sig = _signShared(deactAttId, deactDID, predicate);
        sharedVerifier.submitAttestation(deactAttId, deactDID, predicate, sig);

        // DID is active
        (, bool activeBefore,,) = didRegistry.resolveDID(deactDID);
        assertTrue(activeBefore, "DID should be active");

        // Controller (shared verifier) deactivates the DID
        vm.prank(address(sharedVerifier));
        didRegistry.deactivateDID(deactDID);

        // DID is now deactivated
        (, bool activeAfter,,) = didRegistry.resolveDID(deactDID);
        assertFalse(activeAfter, "DID should be deactivated");

        // Attestation is still stored
        (bool exists,,, bool result,) = sharedVerifier.verifyAttestation(deactAttId);
        assertTrue(exists && result, "Attestation should still be PASS even after DID deactivation");
    }
}
