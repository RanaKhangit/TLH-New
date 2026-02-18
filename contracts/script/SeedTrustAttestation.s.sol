// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title SeedTrustAttestation — Submit a demo attestation to the TrustAttestationVerifier
contract SeedTrustAttestation is Script {
    using MessageHashUtils for bytes32;

    string constant DOMAIN = "TLH_ATTESTATION_V1";

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        // TrustAttestationVerifier proxy from deployment-manifest
        TrustAttestationVerifier verifier =
            TrustAttestationVerifier(0x2Ad7540B14585ebFB3c86604d1927b40e2eFa5db);

        // Use a different attestation ID to avoid replay
        bytes32 attestationId = keccak256("demo-trust-attestation-001");
        bytes32 subjectDID = keccak256(abi.encodePacked("did:tlh:clinician-789"));
        bytes32 predicateType = keccak256(abi.encodePacked("GMC_REGISTERED"));
        bytes32 vcType = keccak256(abi.encodePacked("GMC_REGISTRATION"));
        bytes32 contentHash = keccak256(abi.encodePacked("demo-trust-vc-content-v1"));

        // Build predicateData per ADR-002
        bytes memory abiPayload = abi.encode(
            predicateType,
            true,                           // result
            block.timestamp,                // checkedAt
            uint256(0),                     // expiresAt (0 = non-expiring)
            vcType,
            contentHash,
            bytes("")                       // extraData
        );
        bytes memory predicateData = abi.encodePacked(bytes1(0x01), abiPayload);

        // Chain-bound digest (includes trust verifier address)
        bytes32 digest = keccak256(
            abi.encodePacked(
                DOMAIN,
                block.chainid,
                address(verifier),
                attestationId,
                subjectDID,
                keccak256(predicateData)
            )
        ).toEthSignedMessageHash();

        // Sign with deployer key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.startBroadcast(deployerKey);

        // 1. Add deployer as whitelisted signer
        verifier.addSigner(deployer);
        console.log("Added deployer as trust signer");

        // 2. Submit attestation
        verifier.submitAttestation(attestationId, subjectDID, predicateData, signature);
        console.log("Trust attestation submitted");
        console.logBytes32(attestationId);

        vm.stopBroadcast();
    }
}
