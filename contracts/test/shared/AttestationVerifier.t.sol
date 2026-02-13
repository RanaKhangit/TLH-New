// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {AttestationVerifier} from "../../src/shared/AttestationVerifier.sol";
import {DIDRegistry} from "../../src/shared/DIDRegistry.sol";
import {VCHashAnchors} from "../../src/shared/VCHashAnchors.sol";

contract AttestationVerifierTest is Test {
    using MessageHashUtils for bytes32;

    AttestationVerifier verifier;
    DIDRegistry didReg;
    VCHashAnchors anchors;

    address admin = address(0xA11CE);
    uint256 signerSk = 0xBEEF;
    address signer;

    bytes32 subjectDID = keccak256("did:example:clinician-1");
    bytes32 vcType = keccak256("MedicalLicense");
    bytes32 contentHash = keccak256("vc-content-v1");

    function setUp() public {
        // Warp to a realistic timestamp so that block.timestamp - N doesn't underflow
        vm.warp(1_700_000_000);
        signer = vm.addr(signerSk);

        // Deploy DIDRegistry behind proxy
        DIDRegistry didImpl = new DIDRegistry();
        ERC1967Proxy didProxy = new ERC1967Proxy(address(didImpl), abi.encodeCall(DIDRegistry.initialize, (admin)));
        didReg = DIDRegistry(address(didProxy));

        // Deploy VCHashAnchors behind proxy
        VCHashAnchors anchorImpl = new VCHashAnchors();
        ERC1967Proxy anchorProxy =
            new ERC1967Proxy(address(anchorImpl), abi.encodeCall(VCHashAnchors.initialize, (admin)));
        anchors = VCHashAnchors(address(anchorProxy));

        // Deploy AttestationVerifier behind proxy
        AttestationVerifier verifierImpl = new AttestationVerifier();
        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl),
            abi.encodeCall(AttestationVerifier.initialize, (admin, address(didReg), address(anchors)))
        );
        verifier = AttestationVerifier(address(verifierProxy));

        // Grant roles: verifier can register DIDs and write anchors
        vm.startPrank(admin);
        didReg.grantRole(didReg.REGISTRAR_ROLE(), address(verifier));
        anchors.grantRole(anchors.ANCHOR_WRITER_ROLE(), address(verifier));
        verifier.addSigner(signer);
        vm.stopPrank();
    }

    // -------------------------
    // Helpers
    // -------------------------

    function _buildPredicateData(bool result, uint256 expiresAt) internal view returns (bytes memory) {
        bytes32 predicateType = keccak256("IdentityVerification");
        uint256 checkedAt = block.timestamp;
        bytes memory extra = "";

        bytes memory abiPayload = abi.encode(predicateType, result, checkedAt, expiresAt, vcType, contentHash, extra);

        // predicateData[0] = result byte, predicateData[1:] = ABI-encoded tuple
        return abi.encodePacked(result ? bytes1(0x01) : bytes1(0x00), abiPayload);
    }

    function _buildMismatchPredicateData(bool byteResult, bool abiResult, uint256 expiresAt)
        internal
        view
        returns (bytes memory)
    {
        bytes32 predicateType = keccak256("IdentityVerification");
        uint256 checkedAt = block.timestamp;
        bytes memory extra = "";

        bytes memory abiPayload = abi.encode(predicateType, abiResult, checkedAt, expiresAt, vcType, contentHash, extra);
        return abi.encodePacked(byteResult ? bytes1(0x01) : bytes1(0x00), abiPayload);
    }

    /// @dev F-02: sign with domain + chain-bound digest
    function _sign(bytes32 attestationId, bytes32 did, bytes memory predicateData)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(
                abi.encodePacked(
                    "TLH_ATTESTATION_V1", block.chainid, address(verifier), attestationId, did, keccak256(predicateData)
                )
            ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        return abi.encodePacked(r, s, v);
    }

    // -------------------------
    // Test: Positive attestation (happy path)
    // -------------------------

    function testPositiveAttestationAnchorsAndRegistersDID() public {
        bytes32 attId = keccak256("att-positive-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicateData(true, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        verifier.submitAttestation(attId, subjectDID, predicate, sig);

        // Attestation stored
        (bool exists, bytes32 storedDID,, bool result,) = verifier.verifyAttestation(attId);
        assertTrue(exists);
        assertEq(storedDID, subjectDID);
        assertTrue(result);

        // DID registered
        (address controller, bool active,,) = didReg.resolveDID(subjectDID);
        assertEq(controller, address(verifier));
        assertTrue(active);

        // Anchor written
        (bytes32 hash,, bool revoked) = anchors.getAnchor(subjectDID, vcType);
        assertEq(hash, contentHash);
        assertFalse(revoked);
    }

    // -------------------------
    // Test F-01: Negative attestation must NOT trigger side-effects
    // -------------------------

    function testNegativeAttestationDoesNotAnchorOrRegisterDID() public {
        bytes32 attId = keccak256("att-negative-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicateData(false, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        verifier.submitAttestation(attId, subjectDID, predicate, sig);

        // Attestation is stored (base behavior, allowed by spec)
        (bool exists,,, bool result,) = verifier.verifyAttestation(attId);
        assertTrue(exists);
        assertFalse(result);

        // DID must NOT be registered
        vm.expectRevert(abi.encodeWithSelector(DIDRegistry.DIDNotFound.selector, subjectDID));
        didReg.resolveDID(subjectDID);

        // Anchor must NOT exist
        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorNotFound.selector, subjectDID, vcType));
        anchors.getAnchor(subjectDID, vcType);
    }

    // -------------------------
    // Test F-07: Result mismatch reverts
    // -------------------------

    function testResultMismatchByteTrueAbiFalseReverts() public {
        bytes32 attId = keccak256("att-mismatch-1");
        uint256 expiresAt = block.timestamp + 365 days;
        // byte says true, ABI says false
        bytes memory predicate = _buildMismatchPredicateData(true, false, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        vm.expectRevert(AttestationVerifier.ResultMismatch.selector);
        verifier.submitAttestation(attId, subjectDID, predicate, sig);
    }

    function testResultMismatchByteFalseAbiTrueReverts() public {
        bytes32 attId = keccak256("att-mismatch-2");
        uint256 expiresAt = block.timestamp + 365 days;
        // byte says false, ABI says true
        bytes memory predicate = _buildMismatchPredicateData(false, true, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        vm.expectRevert(AttestationVerifier.ResultMismatch.selector);
        verifier.submitAttestation(attId, subjectDID, predicate, sig);
    }

    // -------------------------
    // Test F-08: Expired credential reverts
    // -------------------------

    function testExpiredCredentialReverts() public {
        bytes32 attId = keccak256("att-expired-1");
        uint256 expiresAt = block.timestamp - 1; // already expired
        bytes memory predicate = _buildPredicateData(true, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        vm.expectRevert(abi.encodeWithSelector(AttestationVerifier.CredentialExpiredOnSubmission.selector, expiresAt));
        verifier.submitAttestation(attId, subjectDID, predicate, sig);
    }

    function testExpiresAtExactlyNowReverts() public {
        bytes32 attId = keccak256("att-expired-exact");
        uint256 expiresAt = block.timestamp; // expiresAt <= block.timestamp
        bytes memory predicate = _buildPredicateData(true, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        vm.expectRevert(abi.encodeWithSelector(AttestationVerifier.CredentialExpiredOnSubmission.selector, expiresAt));
        verifier.submitAttestation(attId, subjectDID, predicate, sig);
    }

    function testZeroExpiresAtAllowed() public {
        bytes32 attId = keccak256("att-no-expiry");
        uint256 expiresAt = 0; // no expiry
        bytes memory predicate = _buildPredicateData(true, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        verifier.submitAttestation(attId, subjectDID, predicate, sig);

        (bool exists,,,,) = verifier.verifyAttestation(attId);
        assertTrue(exists);
    }

    function testNegativeAttestationWithExpiredDoesNotRevert() public {
        // F-08 only applies on the result==true path; negative attestations early-return before expiry check
        bytes32 attId = keccak256("att-neg-expired");
        uint256 expiresAt = block.timestamp - 100;
        bytes memory predicate = _buildPredicateData(false, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        // Should succeed — negative attestations don't check expiry
        verifier.submitAttestation(attId, subjectDID, predicate, sig);

        (bool exists,,, bool result,) = verifier.verifyAttestation(attId);
        assertTrue(exists);
        assertFalse(result);
    }

    // -------------------------
    // Test F-03: Try/catch only swallows DIDAlreadyRegistered
    // -------------------------

    function testDIDAlreadyRegisteredIsSilentlyHandled() public {
        // First attestation registers the DID
        bytes32 attId1 = keccak256("att-dup-did-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate1 = _buildPredicateData(true, expiresAt);
        bytes memory sig1 = _sign(attId1, subjectDID, predicate1);

        verifier.submitAttestation(attId1, subjectDID, predicate1, sig1);

        // Second attestation — DID already registered, should be silently handled
        bytes32 attId2 = keccak256("att-dup-did-2");
        bytes memory predicate2 = _buildPredicateData(true, expiresAt);
        bytes memory sig2 = _sign(attId2, subjectDID, predicate2);

        // Should not revert
        verifier.submitAttestation(attId2, subjectDID, predicate2, sig2);

        (bool exists,,,,) = verifier.verifyAttestation(attId2);
        assertTrue(exists);
    }

    // -------------------------
    // Test F-14: Durable revocation integration
    // -------------------------

    function testRevokedAnchorBlocksNewAttestation() public {
        // First: submit valid attestation, anchor gets created
        bytes32 attId1 = keccak256("att-revoke-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate1 = _buildPredicateData(true, expiresAt);
        bytes memory sig1 = _sign(attId1, subjectDID, predicate1);
        verifier.submitAttestation(attId1, subjectDID, predicate1, sig1);

        // Admin revokes the anchor
        vm.prank(admin);
        anchors.revokeAnchor(subjectDID, vcType);

        // Second attestation should revert because anchorHash will revert with AnchorIsRevoked
        bytes32 attId2 = keccak256("att-revoke-2");
        bytes memory predicate2 = _buildPredicateData(true, expiresAt);
        bytes memory sig2 = _sign(attId2, subjectDID, predicate2);

        vm.expectRevert(abi.encodeWithSelector(VCHashAnchors.AnchorIsRevoked.selector, subjectDID, vcType));
        verifier.submitAttestation(attId2, subjectDID, predicate2, sig2);
    }

    // -------------------------
    // Test: Events emitted correctly
    // -------------------------

    function testPositiveAttestationEmitsCorrectEvents() public {
        bytes32 attId = keccak256("att-events-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicateData(true, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        vm.expectEmit(true, true, false, true);
        emit AttestationVerifier.DIDRegisteredViaAttestation(subjectDID, attId);

        vm.expectEmit(true, true, true, true);
        emit AttestationVerifier.VCHashAnchoredViaAttestation(subjectDID, vcType, contentHash, attId);

        verifier.submitAttestation(attId, subjectDID, predicate, sig);
    }

    function testNegativeAttestationDoesNotEmitAnchorEvents() public {
        bytes32 attId = keccak256("att-neg-events-1");
        uint256 expiresAt = block.timestamp + 365 days;
        bytes memory predicate = _buildPredicateData(false, expiresAt);
        bytes memory sig = _sign(attId, subjectDID, predicate);

        // We record logs and verify no VCHashAnchoredViaAttestation event was emitted
        vm.recordLogs();
        verifier.submitAttestation(attId, subjectDID, predicate, sig);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Only AttestationSubmitted should be present (from base), no anchor/DID events
        bytes32 anchorEventSig = keccak256("VCHashAnchoredViaAttestation(bytes32,bytes32,bytes32,bytes32)");
        bytes32 didEventSig = keccak256("DIDRegisteredViaAttestation(bytes32,bytes32)");

        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(logs[i].topics[0] != anchorEventSig, "Unexpected VCHashAnchoredViaAttestation event");
            assertTrue(logs[i].topics[0] != didEventSig, "Unexpected DIDRegisteredViaAttestation event");
        }
    }
}
