// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BaseAttestationVerifier} from "../../src/base/BaseAttestationVerifier.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BaseVerifierHarness is BaseAttestationVerifier {
    function initialize(address admin) external initializer {
        __BaseAttestationVerifier_init(admin);
    }

    function submit(bytes32 attestationId, bytes32 subjectDID, bytes calldata predicateData, bytes calldata signature)
        external
        returns (bool)
    {
        return _verifyAndStore(attestationId, subjectDID, predicateData, signature);
    }

    function _onAttestationVerified(bytes32, bytes32, bytes calldata, bool) internal override {}
}

contract BaseAttestationVerifierTest is Test {
    using MessageHashUtils for bytes32;

    BaseVerifierHarness h;

    uint256 signerSk;
    address signer;
    address admin = address(0xA11CE);

    bytes32 constant PRED_TYPE = keccak256("GMC_REGISTERED");
    bytes32 constant VC_TYPE = keccak256("GMC_LICENSE");
    bytes32 constant CONTENT_HASH = keccak256("content");

    function setUp() public {
        vm.warp(1_700_000_000);

        h = new BaseVerifierHarness();
        h.initialize(admin);

        signerSk = 0xBEEF;
        signer = vm.addr(signerSk);

        vm.prank(admin);
        h.addSigner(signer);
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
                abi.encode(
                    "TLH_ATTESTATION_V1", block.chainid, address(h), attestationId, subjectDID, keccak256(predicateData)
                )
            ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ---- signer management ----

    function testAddRemoveSignerAccessControl() public {
        address other = address(0xB0B);

        vm.expectRevert();
        vm.prank(other);
        h.addSigner(other);

        vm.prank(admin);
        h.addSigner(other);

        vm.prank(admin);
        h.removeSigner(other);
    }

    // ---- valid submission ----

    function testValidSignatureStoresAndEmits() public {
        bytes32 attId = keccak256("att-1");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 1 days);

        bytes memory sig = _sign(attId, did, predicate);

        vm.expectEmit(true, true, false, true);
        emit BaseAttestationVerifier.AttestationSubmitted(attId, did, true, block.timestamp);

        bool result = h.submit(attId, did, predicate, sig);
        assertTrue(result);
    }

    function testFalseResultSubmission() public {
        bytes32 attId = keccak256("att-false");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(false, block.timestamp, block.timestamp + 1 days);

        bytes memory sig = _sign(attId, did, predicate);

        bool result = h.submit(attId, did, predicate, sig);
        assertFalse(result);
    }

    // ---- empty predicate ----

    function testEmptyPredicateReverts() public {
        bytes32 attId = keccak256("att-2");
        bytes32 did = keccak256("did");
        bytes memory predicate = "";
        bytes memory sig = "0x00";

        vm.expectRevert(BaseAttestationVerifier.EmptyPredicateData.selector);
        h.submit(attId, did, predicate, sig);
    }

    // ---- duplicate ----

    function testDuplicateAttestationReverts() public {
        bytes32 attId = keccak256("att-3");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 1 days);
        bytes memory sig = _sign(attId, did, predicate);

        h.submit(attId, did, predicate, sig);

        vm.expectRevert(abi.encodeWithSelector(BaseAttestationVerifier.DuplicateAttestation.selector, attId));
        h.submit(attId, did, predicate, sig);
    }

    // ---- unauthorized signer ----

    function testUnauthorizedSignerReverts() public {
        uint256 badSk = 0xCAFE;
        address badSigner = vm.addr(badSk);

        bytes32 attId = keccak256("att-4");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(true, block.timestamp, block.timestamp + 1 days);

        bytes32 digest = keccak256(
                abi.encode("TLH_ATTESTATION_V1", block.chainid, address(h), attId, did, keccak256(predicate))
            ).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(badSk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(BaseAttestationVerifier.UnauthorizedSigner.selector, badSigner));
        h.submit(attId, did, predicate, sig);
    }

    // ---- result mismatch ----

    function testResultMismatchReverts() public {
        bytes32 attId = keccak256("att-mismatch");
        bytes32 did = keccak256("did");

        // result byte = 0x01 (true) but ABI-encoded result = false → mismatch
        bytes memory encoded =
            abi.encode(PRED_TYPE, false, block.timestamp, block.timestamp + 1 days, VC_TYPE, CONTENT_HASH, bytes(""));
        bytes memory predicate = abi.encodePacked(bytes1(0x01), encoded);

        bytes memory sig = _sign(attId, did, predicate);

        vm.expectRevert(BaseAttestationVerifier.ResultMismatch.selector);
        h.submit(attId, did, predicate, sig);
    }

    // ---- expiry enforcement ----

    function testExpiredPositiveAttestationReverts() public {
        uint256 expiry = block.timestamp - 1;

        bytes32 attId = keccak256("att-expired");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(true, block.timestamp - 2, expiry);

        bytes memory sig = _sign(attId, did, predicate);

        vm.expectRevert(
            abi.encodeWithSelector(BaseAttestationVerifier.ExpiredAttestation.selector, expiry, block.timestamp)
        );
        h.submit(attId, did, predicate, sig);
    }

    function testExpiredNegativeAttestationAllowed() public {
        uint256 expiry = block.timestamp - 1;

        bytes32 attId = keccak256("att-exp-neg");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(false, block.timestamp - 2, expiry);

        bytes memory sig = _sign(attId, did, predicate);

        bool result = h.submit(attId, did, predicate, sig);
        assertFalse(result);
    }

    function testNonExpiringPositiveAttestationAllowed() public {
        bytes32 attId = keccak256("att-noexpiry");
        bytes32 did = keccak256("did");
        bytes memory predicate = _buildPredicate(true, block.timestamp, 0);

        bytes memory sig = _sign(attId, did, predicate);

        bool result = h.submit(attId, did, predicate, sig);
        assertTrue(result);
    }
}
