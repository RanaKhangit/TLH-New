pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IAccessControlMinimal {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
}

interface IVCHashAnchors {
    function anchorHash(bytes32 subjectDID, bytes32 vcType, bytes32 contentHash) external;
    function getAnchor(bytes32 subjectDID, bytes32 vcType) external view returns (bytes32, uint256, bool);
}

contract VCHashAnchorsForkTest is Test {
    // ---- Sepolia deployed proxy ----
    address constant VCA_PROXY = 0x95D02Ae28D6fa86f67F121bA36d9cbD363AaFc68;

    // ---- Known deployer/admin (from your live state) ----
    address constant DEPLOYER = 0x3B50966A8B71f277e90e14cdC31455F6Af3977e6;

    // ---- Known writer role hash (from your live state) ----
    bytes32 constant WRITER_ROLE =
        bytes32(0x643166187aa8fc6f848c79a4a271962e5d46421fc8ea97688e834ff77cdeccd1);

    // ---- Known anchored tuple from your verified run ----
    bytes32 constant SUBJECT_DID =
        bytes32(0x26177363be9290a0aa5ebd31f0bfb857e06970248e8700732272020a105e4d83); // keccak("did:tlh:patient-123")
    bytes32 constant VC_TYPE =
        bytes32(0x325fde5952cbd1f70c031c3b5c38334e63a84f8b4550ac0f87a9b252a1e2fb36); // keccak("HealthCredential")
    bytes32 constant CONTENT_HASH =
        bytes32(0x346329ecf03838aae202530cea9d1a3fda878e1c5d79defacdb8976ea141851c); // sha256(canonical vc.json)

    // ---- Event signature topic0 observed on-chain for Anchor event ----
    // From your tx logs: topics[0] = 0x56219d8636...de7a7f0f
    bytes32 constant ANCHOR_EVENT_TOPIC0 =
        bytes32(0x56219d86361349ba9ae3fe61ea05c86e52312c3e6bbf39e48abdd0a4de7a7f0f);

    IVCHashAnchors vca = IVCHashAnchors(VCA_PROXY);
    IAccessControlMinimal ac = IAccessControlMinimal(VCA_PROXY);

    function setUp() public {
        string memory rpc = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpc);
        assertEq(block.chainid, 11155111);
    }

    function test_roles_deployer_has_admin_and_writer() public view {
        bytes32 admin = ac.DEFAULT_ADMIN_ROLE();
        assertTrue(ac.hasRole(admin, DEPLOYER), "deployer missing DEFAULT_ADMIN_ROLE");
        assertTrue(ac.hasRole(WRITER_ROLE, DEPLOYER), "deployer missing WRITER_ROLE");
    }

    function test_unauthorized_anchor_reverts() public {
        address attacker = address(0xBEEF);
        assertFalse(ac.hasRole(WRITER_ROLE, attacker), "attacker unexpectedly has WRITER_ROLE");

        vm.startPrank(attacker);
        vm.expectRevert();
        vca.anchorHash(SUBJECT_DID, VC_TYPE, CONTENT_HASH);
        vm.stopPrank();
    }

    function test_getAnchor_returns_expected_tuple() public view {
        (bytes32 onchainHash, uint256 anchoredAt, bool revoked) = vca.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(onchainHash, CONTENT_HASH, "contentHash mismatch");
        assertTrue(anchoredAt != 0, "anchoredAt should be non-zero");
        assertEq(revoked, false, "revoked should be false");
    }

    function test_getAnchor_missing_pair_reverts() public {
        bytes32 missingType = keccak256("MissingCredentialType");
        vm.expectRevert();
        vca.getAnchor(SUBJECT_DID, missingType);
    }

    function test_reanchor_updates_anchoredAt_and_keeps_hash() public {
        (bytes32 beforeHash, uint256 beforeAt, bool beforeRevoked) = vca.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(beforeHash, CONTENT_HASH, "pre: contentHash mismatch");
        assertEq(beforeRevoked, false, "pre: revoked should be false");

        uint256 newTs = beforeAt + 3600;
        vm.warp(newTs);
        vm.roll(block.number + 1);

        vm.startPrank(DEPLOYER);
        vca.anchorHash(SUBJECT_DID, VC_TYPE, CONTENT_HASH);
        vm.stopPrank();

        (bytes32 afterHash, uint256 afterAt, bool afterRevoked) = vca.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(afterHash, CONTENT_HASH, "post: contentHash mismatch");
        assertEq(afterRevoked, false, "post: revoked should be false");
        assertTrue(afterAt >= newTs, "anchoredAt did not move forward as expected");
    }

    function test_writer_role_admin_is_default_admin() public view {
        bytes32 admin = ac.DEFAULT_ADMIN_ROLE();
        bytes32 roleAdmin = ac.getRoleAdmin(WRITER_ROLE);
        assertEq(roleAdmin, admin, "WRITER_ROLE admin should be DEFAULT_ADMIN_ROLE");
    }

    // -------------------------------------------------------------------------
    // NEW TEST 1: Event assertions (topics + data decode)
    // -------------------------------------------------------------------------
    function test_anchor_emits_expected_event_topics_and_data() public {
        // Move time forward so timestamp is clearly >= target
        (bytes32 _h, uint256 _t, bool _r) = vca.getAnchor(SUBJECT_DID, VC_TYPE); _h; _t; _r; // ensure pair exists / no revert
        uint256 targetTs = block.timestamp + 1234;
        vm.warp(targetTs);
        vm.roll(block.number + 1);

        vm.recordLogs();

        vm.startPrank(DEPLOYER);
        vca.anchorHash(SUBJECT_DID, VC_TYPE, CONTENT_HASH);
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Find the VCA proxy log with expected topic0
        bool found;
        bytes32 t0;
        bytes32 t1;
        bytes32 t2;
        bytes32 dataHash;
        uint256 dataTs;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].emitter != VCA_PROXY) continue;
            if (entries[i].topics.length < 3) continue;
            if (entries[i].topics[0] != ANCHOR_EVENT_TOPIC0) continue;

            found = true;
            t0 = entries[i].topics[0];
            t1 = entries[i].topics[1];
            t2 = entries[i].topics[2];

            (dataHash, dataTs) = abi.decode(entries[i].data, (bytes32, uint256));
            break;
        }

        assertTrue(found, "expected anchor event log not found");
        assertEq(t0, ANCHOR_EVENT_TOPIC0, "topic0 mismatch");
        assertEq(t1, SUBJECT_DID, "topic1 should be subjectDID");
        assertEq(t2, VC_TYPE, "topic2 should be vcType");
        assertEq(dataHash, CONTENT_HASH, "event data contentHash mismatch");
        assertEq(dataTs, block.timestamp, "event timestamp should equal current block.timestamp");
    }

    // -------------------------------------------------------------------------
    // NEW TEST 2: Content-hash change behavior (revert OR overwrite)
    // This test is *behavior-discovery-safe*:
    // - If contract forbids changing contentHash for same (subjectDID, vcType), we assert revert and unchanged state.
    // - If contract allows overwrite, we assert new hash stored and anchoredAt advanced.
    // -------------------------------------------------------------------------
    function test_contentHash_change_behavior_is_consistent() public {
        (bytes32 beforeHash, uint256 beforeAt, bool beforeRevoked) = vca.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(beforeRevoked, false, "pre: revoked should be false");
        assertTrue(beforeAt != 0, "pre: anchoredAt should be non-zero");

        // Different content hash
        bytes32 newHash = keccak256("different-content-hash-for-behavior-test");
        assertTrue(newHash != beforeHash, "newHash unexpectedly equals beforeHash");

        uint256 targetTs = beforeAt + 7200;
        vm.warp(targetTs);
        vm.roll(block.number + 1);

        // Attempt re-anchor with different content hash
        bool reverted;
        vm.startPrank(DEPLOYER);
        try vca.anchorHash(SUBJECT_DID, VC_TYPE, newHash) {
            reverted = false;
        } catch {
            reverted = true;
        }
        vm.stopPrank();

        (bytes32 afterHash, uint256 afterAt, bool afterRevoked) = vca.getAnchor(SUBJECT_DID, VC_TYPE);
        assertEq(afterRevoked, false, "post: revoked should be false");

        if (reverted) {
            // Semantics: immutability for contentHash per key
            assertEq(afterHash, beforeHash, "contentHash changed but tx reverted");
            assertEq(afterAt, beforeAt, "anchoredAt changed but tx reverted");
        } else {
            // Semantics: overwrite allowed
            assertEq(afterHash, newHash, "overwrite allowed but contentHash not updated");
            assertTrue(afterAt >= targetTs, "overwrite allowed but anchoredAt did not advance");
        }
    }
}


