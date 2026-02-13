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

    function setUp() public {
        h = new BaseVerifierHarness();
        h.initialize(admin);

        signerSk = 0xBEEF;
        signer = vm.addr(signerSk);

        vm.prank(admin);
        h.addSigner(signer);
    }

    function _sign(bytes32 attestationId, bytes32 subjectDID, bytes memory predicateData)
        internal
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(attestationId, subjectDID, keccak256(predicateData)))
            .toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerSk, digest);
        return abi.encodePacked(r, s, v);
    }

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

    function testValidSignatureStoresAndEmits() public {
        bytes32 attId = keccak256("att-1");
        bytes32 did = keccak256("did");
        bytes memory predicate = hex"01abcdef";

        bytes memory sig = _sign(attId, did, predicate);

        vm.expectEmit(true, true, false, true);
        emit BaseAttestationVerifier.AttestationSubmitted(attId, did, true, block.timestamp);

        bool result = h.submit(attId, did, predicate, sig);
        assertTrue(result);
    }

    function testEmptyPredicateReverts() public {
        bytes32 attId = keccak256("att-2");
        bytes32 did = keccak256("did");
        bytes memory predicate = "";

        bytes memory sig = "0x00";

        vm.expectRevert(BaseAttestationVerifier.EmptyPredicateData.selector);
        h.submit(attId, did, predicate, sig);
    }

    function testDuplicateAttestationReverts() public {
        bytes32 attId = keccak256("att-3");
        bytes32 did = keccak256("did");
        bytes memory predicate = hex"01aa";
        bytes memory sig = _sign(attId, did, predicate);

        h.submit(attId, did, predicate, sig);

        vm.expectRevert(abi.encodeWithSelector(BaseAttestationVerifier.DuplicateAttestation.selector, attId));
        h.submit(attId, did, predicate, sig);
    }

    function testUnauthorizedSignerReverts() public {
        uint256 badSk = 0xCAFE;
        address badSigner = vm.addr(badSk);

        bytes32 attId = keccak256("att-4");
        bytes32 did = keccak256("did");
        bytes memory predicate = hex"01bb";

        bytes32 digest = keccak256(abi.encodePacked(attId, did, keccak256(predicate))).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(badSk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(BaseAttestationVerifier.UnauthorizedSigner.selector, badSigner));
        h.submit(attId, did, predicate, sig);
    }
}
