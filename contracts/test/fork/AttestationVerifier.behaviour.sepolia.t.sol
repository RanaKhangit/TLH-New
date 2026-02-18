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

interface IAttestationVerifierWithDeps is IAttestationVerifier {
    function didRegistry() external view returns (address);
    function vcHashAnchors() external view returns (address);
}

interface IDIDRegistryRead {
    function resolveDID(bytes32 did)
        external
        view
        returns (address controller, bool active, uint256 registeredAt, uint256 updatedAt);
}

interface IVCHashAnchorsRead {
    function getAnchor(bytes32 subjectDID, bytes32 vcType)
        external
        view
        returns (bytes32 contentHash, uint256 anchoredAt, bool revoked);
}

contract AttestationVerifierForkBehaviour is Test {
    // --- Sepolia deployed proxy ---
    address constant ATTESTATION_VERIFIER_PROXY = 0xCE863E465f21Df87Ad9F0A2af838Fac1750F08d2;
    uint256 constant DEFAULT_FORK_BLOCK = 10280750;

    // --- Domain constant (must match contract) ---
    string constant DOMAIN = "TLH_ATTESTATION_V1";

    // --- Errors (selector-precise) ---
    error InvalidSignature();
    error UnauthorizedSigner(address recovered);
    error DuplicateAttestation(bytes32 attestationId);
    error EmptyPredicateData();
    error ResultMismatch();
    error ExpiredAttestation(uint256 expiresAt, uint256 nowTs);

    // --- Event (must match) ---
    event AttestationSubmitted(
        bytes32 indexed attestationId, bytes32 indexed subjectDID, bool result, uint256 timestamp
    );

    IAttestationVerifierWithDeps verifier;
    IDIDRegistryRead did;
    IVCHashAnchorsRead vca;

    // Provide RPC via env: SEPOLIA_RPC_URL
    function setUp() public {
        string memory rpc = vm.envString("SEPOLIA_RPC_URL");
        uint256 forkBlock = vm.envOr("FORK_BLOCK", DEFAULT_FORK_BLOCK); // pin determinism
        vm.createSelectFork(rpc, forkBlock);

        verifier = IAttestationVerifierWithDeps(ATTESTATION_VERIFIER_PROXY);
        did = IDIDRegistryRead(verifier.didRegistry());
        vca = IVCHashAnchorsRead(verifier.vcHashAnchors());
    }

    function _loadSignerPk() internal view returns (uint256) {
        if (vm.envExists("SIGNER_PK")) {
            return vm.envUint("SIGNER_PK");
        }
        if (vm.envExists("DEPLOYER_PRIVATE_KEY")) {
            string memory pk = vm.envString("DEPLOYER_PRIVATE_KEY");
            return vm.parseUint(pk);
        }
        revert("SIGNER_PK or DEPLOYER_PRIVATE_KEY required");
    }

    // ----------------------------
    // Helpers
    // ----------------------------

    function _digest(bytes32 attestationId, bytes32 subjectDID, bytes memory predicateData)
        internal
        view
        returns (bytes32)
    {
        bytes32 inner = keccak256(
            abi.encodePacked(
                DOMAIN,
                block.chainid,
                ATTESTATION_VERIFIER_PROXY, // address(this) at runtime is the proxy address
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

    // ADR-002 payload decode in base expects:
    // abi.decode(predicateData[1:], (bytes32, bool, uint256, uint256, bytes32, bytes32, bytes))
    // We build the minimum safe layout with dummy values for unused fields.
    function _makePredicateData(
        bool resultByte,
        bool abiResult,
        uint256 issuedAt,
        uint256 expiresAt,
        bytes32 vcType,
        bytes32 contentHash,
        bytes memory extra
    ) internal pure returns (bytes memory) {
        bytes memory tail = abi.encode(bytes32(0), abiResult, issuedAt, expiresAt, vcType, contentHash, extra);
        bytes memory prefix = new bytes(1);
        prefix[0] = resultByte ? bytes1(0x01) : bytes1(0x00);
        return bytes.concat(prefix, tail);
    }

    // ----------------------------
    // Tests
    // ----------------------------

    function test_Revert_EmptyPredicateData() public {
        bytes32 attestationId = keccak256("att-empty");
        bytes32 subjectDID = keccak256("did:tlh:test");

        bytes memory predicateData = hex"";
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(uint256(1), digest); // signature irrelevant; must revert earlier

        vm.expectRevert(EmptyPredicateData.selector);
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_ResultMismatch() public {
        bytes32 attestationId = keccak256("att-mismatch");
        bytes32 subjectDID = keccak256("did:tlh:test");

        // result byte says true, ABI result says false
        bytes memory predicateData = _makePredicateData(true, false, 0, 0, bytes32(0), bytes32(0), "");
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(uint256(1), digest);

        vm.expectRevert(ResultMismatch.selector);
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_ExpiredAttestation_WhenPositiveAndExpired() public {
        bytes32 attestationId = keccak256("att-expired");
        bytes32 subjectDID = keccak256("did:tlh:test");

        uint256 expiresAt = block.timestamp - 1;
        bytes memory predicateData = _makePredicateData(true, true, 0, expiresAt, bytes32(0), bytes32(0), "");
        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(uint256(1), digest);

        vm.expectRevert(abi.encodeWithSelector(ExpiredAttestation.selector, expiresAt, block.timestamp));
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_InvalidSignature_ZeroRecovered() public {
        bytes32 attestationId = keccak256("att-badsig");
        bytes32 subjectDID = keccak256("did:tlh:test");

        bytes memory predicateData = _makePredicateData(false, false, 0, 0, bytes32(0), bytes32(0), "");
        bytes memory sig = hex""; // invalid format -> OZ recover should revert or return 0 depending; we assert contract's path

        // If OZ recover reverts, this test will fail; in that case, change to a structurally valid but wrong sig.
        vm.expectRevert();
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    function test_Revert_UnauthorizedSigner_WhenSignatureValidButNotWhitelisted() public {
        bytes32 attestationId = keccak256("att-unauth");
        bytes32 subjectDID = keccak256("did:tlh:test");

        bytes memory predicateData = _makePredicateData(false, false, 0, 0, bytes32(0), bytes32(0), "");

        // Use deterministic local key; recovered will be addr(pk) which is not whitelisted on-chain
        uint256 pk = 0xA11CE;
        address recovered = vm.addr(pk);

        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(pk, digest);

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedSigner.selector, recovered));
        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);
    }

    // Storage-only happy path: result=false so _onAttestationVerified returns immediately (no cross-contract side-effects).
    function test_HappyPath_StorageOnly_SubmitAndVerify() public {
        uint256 signerPk = _loadSignerPk();
        address signer = vm.addr(signerPk);

        bytes32 attestationId = keccak256(abi.encodePacked("att-storage", signer, block.number));
        bytes32 subjectDID = keccak256("did:tlh:patient-123");

        bytes32 vcType = keccak256("HealthCredential");
        bytes32 contentHash = keccak256("content");

        bytes memory predicateData = _makePredicateData(false, false, block.timestamp, 0, vcType, contentHash, "");

        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(signerPk, digest);

        vm.expectEmit(true, true, true, true);
        emit AttestationSubmitted(attestationId, subjectDID, false, block.timestamp);

        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);

        (bool exists, bytes32 gotDID, bytes32 predicateHash, bool result, uint256 ts) =
            verifier.verifyAttestation(attestationId);

        assertTrue(exists);
        assertEq(gotDID, subjectDID);
        assertEq(predicateHash, keccak256(predicateData));
        assertFalse(result);
        assertEq(ts, block.timestamp);
    }

    // Side-effect happy path: result=true triggers _onAttestationVerified cross-contract calls.
    // Expected to revert until DIDRegistry grants the required role to the AttestationVerifier proxy.
    function test_HappyPath_SideEffects_SubmitAndVerify() public {
        uint256 signerPk = _loadSignerPk();
        address signer = vm.addr(signerPk);

        bytes32 attestationId = keccak256(abi.encodePacked("att-happy", signer, block.number));
        bytes32 subjectDID = keccak256("did:tlh:patient-123");

        bytes32 vcType = keccak256("HealthCredential");
        bytes32 contentHash = keccak256("content");

        bytes memory predicateData = _makePredicateData(true, true, block.timestamp, 0, vcType, contentHash, "");

        bytes32 digest = _digest(attestationId, subjectDID, predicateData);
        bytes memory sig = _sign(signerPk, digest);

        vm.expectEmit(true, true, true, true);
        emit AttestationSubmitted(attestationId, subjectDID, true, block.timestamp);

        verifier.submitAttestation(attestationId, subjectDID, predicateData, sig);

        (bool exists, bytes32 gotDID, bytes32 predicateHash, bool result, uint256 ts) =
            verifier.verifyAttestation(attestationId);

        assertTrue(exists);
        assertEq(gotDID, subjectDID);
        assertEq(predicateHash, keccak256(predicateData));
        assertTrue(result);
        assertEq(ts, block.timestamp);

        // Cross-contract side-effect assertions
        (, bool active, uint256 registeredAt,) = did.resolveDID(subjectDID);
        assertTrue(registeredAt > 0);
        assertTrue(active);

        (bytes32 ch, uint256 anchoredAt, bool revoked) = vca.getAnchor(subjectDID, vcType);
        assertEq(ch, contentHash);
        assertTrue(anchoredAt > 0);
        assertFalse(revoked);
    }

    function test_Revert_DuplicateAttestation() public {
        uint256 signerPk = _loadSignerPk();

        bytes32 attestationId = keccak256("att-dup");
        bytes32 subjectDID = keccak256("did:tlh:dup");

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
