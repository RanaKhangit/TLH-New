// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IAttestationVerifier {
    function submitAttestation(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bytes calldata signature
    ) external;

    function verifyAttestation(bytes32 attestationId)
        external
        view
        returns (bool exists, bytes32 subjectDID, bytes32 predicateHash, bool result, uint256 timestamp);
}

interface ITrustAttestationVerifierWithDeps is IAttestationVerifier {
    function credentialRegistry() external view returns (address);
}

interface ICredentialRegistryRead {
    enum CredentialStatus { Active, Expired, Revoked }

    struct Credential {
        bytes32 subjectDID;
        bytes32 predicateType;
        bool valid;
        uint256 checkedAt;
        uint256 expiresAt;
        bytes32 attestationId;
        CredentialStatus status;
    }

    function getCredential(bytes32 subjectDID, bytes32 predicateType) external view returns (Credential memory);
    function isCredentialValid(bytes32 subjectDID, bytes32 predicateType) external view returns (bool);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

contract TrustAttestationVerifierForkBehaviour is Test {
    // --- Sepolia deployed proxy ---
    address constant TRUST_ATTESTATION_VERIFIER_PROXY = 0x2Ad7540B14585ebFB3c86604d1927b40e2eFa5db;

    // --- Domain constant (must match contract) ---
    string constant DOMAIN = "TLH_ATTESTATION_V1";

    // --- Errors (selector-precise, matching BaseAttestationVerifier) ---
    error InvalidSignature();
    error UnauthorizedSigner(address recovered);
    error DuplicateAttestation(bytes32 attestationId);
    error EmptyPredicateData();
    error ResultMismatch();
    error ExpiredAttestation(uint256 expiresAt, uint256 nowTs);

    // --- Events ---
    event AttestationSubmitted(bytes32 indexed attestationId, bytes32 indexed subjectDID, bool result, uint256 timestamp);
    event CredentialWrittenViaAttestation(bytes32 indexed subjectDID, bytes32 indexed predicateType, bytes32 indexed attestationId);

    ITrustAttestationVerifierWithDeps verifier;
    ICredentialRegistryRead credReg;

    // Provide RPC via env: SEPOLIA_RPC_URL
    function setUp() public {
        string memory rpc = vm.envString("SEPOLIA_RPC_URL");
        uint256 forkBlock = vm.envUint("FORK_BLOCK"); // pin determinism
        vm.createSelectFork(rpc, forkBlock);

        verifier = ITrustAttestationVerifierWithDeps(TRUST_ATTESTATION_VERIFIER_PROXY);
        credReg = ICredentialRegistryRead(verifier.credentialRegistry());
    }

    // ----------------------------
    // Helpers
    // ----------------------------

    function _digest(bytes32 attestationId, bytes32 subjectDID, bytes memory predicateData) internal view returns (bytes32) {
        bytes32 inner = keccak256(
            abi.encodePacked(
                DOMAIN,
                block.chainid,
                TRUST_ATTESTATION_VERIFIER_PROXY,
                attestationId,
                subjectDID,
                keccak256(predicateData)
            )
        );
        // EIP-191 personal-sign hash
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
    }

    function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory sig) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    // ADR-002 payload: predicateData[0] = result byte, [1:] = abi.encode(predicateType, result, issuedAt, expiresAt, vcType, contentHash, extra)
    function _makePredicateData(
        bool resultByte,
        bool abiResult,
        uint256 issuedAt,
        uint256 expiresAt,
        bytes32 predicateType,
        bytes32 contentHash,
        bytes memory extra
    ) internal pure returns (bytes memory) {
        bytes memory tail = abi.encode(predicateType, abiResult, issuedAt, expiresAt, bytes32(0), contentHash, extra);
        bytes memory prefix = new bytes(1);
        prefix[0] = resultByte ? bytes1(0x01) : bytes1(0x00);
        return bytes.concat(prefix, tail);
    }

    // ----------------------------
    // Revert Tests
    // ----------------------------

    function test_Revert_EmptyPredicateData() public {
        bytes32 attestationId = keccak256("trust-att-empty");
        bytes32 subjectDID = keccak256("did:tlh:trust-test");

        bytes memory predicateData = hex"";
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(uint256(1), digest);

        vm.expectRevert(EmptyPredicateData.selector);
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_ResultMismatch() public {
        bytes32 attestationId = keccak256("trust-att-mismatch");
        bytes32 subjectDID = keccak256("did:tlh:trust-test");

        // result byte says true, ABI result says false
        bytes memory predicateData = _makePredicateData(true, false, 0, 0, bytes32(0), bytes32(0), "");
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(uint256(1), digest);

        vm.expectRevert(ResultMismatch.selector);
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_ExpiredAttestation_WhenPositiveAndExpired() public {
        bytes32 attestationId = keccak256("trust-att-expired");
        bytes32 subjectDID = keccak256("did:tlh:trust-test");

        uint256 expiresAt = block.timestamp - 1;
        bytes memory predicateData = _makePredicateData(true, true, 0, expiresAt, bytes32(0), bytes32(0), "");
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(uint256(1), digest);

        vm.expectRevert(abi.encodeWithSelector(ExpiredAttestation.selector, expiresAt, block.timestamp));
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_InvalidSignature_ZeroRecovered() public {
        bytes32 attestationId = keccak256("trust-att-badsig");
        bytes32 subjectDID = keccak256("did:tlh:trust-test");

        bytes memory predicateData = _makePredicateData(false, false, 0, 0, bytes32(0), bytes32(0), "");
        bytes memory sig = hex"";

        vm.expectRevert();
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_UnauthorizedSigner_WhenSignatureValidButNotWhitelisted() public {
        bytes32 attestationId = keccak256("trust-att-unauth");
        bytes32 subjectDID = keccak256("did:tlh:trust-test");

        bytes memory predicateData = _makePredicateData(false, false, 0, 0, bytes32(0), bytes32(0), "");

        uint256 pk = 0xA11CE;
        address recovered = vm.addr(pk);

        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(pk, digest);

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedSigner.selector, recovered));
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    // ----------------------------
    // Happy Path Tests
    // ----------------------------

    // Storage-only: result=false so _onAttestationVerified returns immediately (no CredentialRegistry write).
    function test_HappyPath_StorageOnly_SubmitAndVerify() public {
        uint256 signerPk = vm.envUint("SIGNER_PK");
        address signer = vm.addr(signerPk);

        bytes32 attestationId = keccak256(abi.encodePacked("trust-att-storage", signer, block.number));
        bytes32 subjectDID = keccak256("did:tlh:clinician-456");

        bytes32 predicateType = keccak256("GMC_REGISTERED");
        bytes32 contentHash = keccak256("trust-content");

        bytes memory predicateData = _makePredicateData(false, false, block.timestamp, 0, predicateType, contentHash, "");

        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(signerPk, digest);

        vm.expectEmit(true, true, true, true);
        emit AttestationSubmitted(attestationId, subjectDID, false, block.timestamp);

        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);

        (bool exists, bytes32 gotDID, bytes32 predicateHash, bool result, uint256 ts) = verifier.verifyAttestation(attestationId);

        assertTrue(exists);
        assertEq(gotDID, subjectDID);
        assertEq(predicateHash, keccak256(predicateData));
        assertFalse(result);
        assertEq(ts, block.timestamp);
    }

    // Side-effects: result=true triggers credentialRegistry.writeCredential().
    // Expected to revert until CredentialRegistry grants VERIFIER_ROLE to TrustAttestationVerifier proxy.
    function test_HappyPath_SideEffects_SubmitAndVerify() public {
        uint256 signerPk = vm.envUint("SIGNER_PK");
        address signer = vm.addr(signerPk);

        bytes32 attestationId = keccak256(abi.encodePacked("trust-att-happy", signer, block.number));
        bytes32 subjectDID = keccak256("did:tlh:clinician-789");

        bytes32 predicateType = keccak256("GMC_REGISTERED");
        bytes32 contentHash = keccak256("trust-content");

        bytes memory predicateData = _makePredicateData(true, true, block.timestamp, 0, predicateType, contentHash, "");

        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(signerPk, digest);

        vm.expectEmit(true, true, true, true);
        emit AttestationSubmitted(attestationId, subjectDID, true, block.timestamp);

        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);

        // Verify attestation stored
        (bool exists, bytes32 gotDID, bytes32 predicateHash, bool result, uint256 ts) = verifier.verifyAttestation(attestationId);

        assertTrue(exists);
        assertEq(gotDID, subjectDID);
        assertEq(predicateHash, keccak256(predicateData));
        assertTrue(result);
        assertEq(ts, block.timestamp);

        // Cross-contract side-effect: CredentialRegistry assertions
        ICredentialRegistryRead.Credential memory cred = credReg.getCredential(subjectDID, predicateType);
        assertEq(cred.subjectDID, subjectDID);
        assertEq(cred.predicateType, predicateType);
        assertTrue(cred.valid);
        assertEq(cred.attestationId, attestationId);
        assertTrue(cred.checkedAt > 0);
        assertTrue(cred.status == ICredentialRegistryRead.CredentialStatus.Active);

        assertTrue(credReg.isCredentialValid(subjectDID, predicateType));
    }

    // ----------------------------
    // Duplicate Test
    // ----------------------------

    function test_Revert_DuplicateAttestation() public {
        uint256 signerPk = vm.envUint("SIGNER_PK");

        bytes32 attestationId = keccak256("trust-att-dup");
        bytes32 subjectDID = keccak256("did:tlh:trust-dup");

        bytes memory predicateData = _makePredicateData(false, false, block.timestamp, 0, bytes32(0), bytes32(0), "");
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(signerPk, digest);

        // First submit should succeed IF signer is whitelisted.
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);

        // Second must revert
        vm.expectRevert(abi.encodeWithSelector(DuplicateAttestation.selector, attestationId));
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }
}
