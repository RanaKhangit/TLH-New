// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {AttestationVerifier} from "../src/shared/AttestationVerifier.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title SeedAttestation — Submit a demo attestation to the Shared AttestationVerifier
contract SeedAttestation is Script {
    using MessageHashUtils for bytes32;

    string constant DOMAIN = "TLH_ATTESTATION_V1";

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        AttestationVerifier verifier = AttestationVerifier(0xCE863E465f21Df87Ad9F0A2af838Fac1750F08d2);

        // Attestation parameters
        bytes32 attestationId = keccak256("demo-attestation-001");
        bytes32 subjectDID = keccak256(abi.encodePacked("did:tlh:clinician-789"));
        bytes32 predicateType = keccak256(abi.encodePacked("GMC_REGISTERED"));
        bytes32 vcType = keccak256(abi.encodePacked("GMC_REGISTRATION"));
        bytes32 contentHash = keccak256(abi.encodePacked("demo-vc-content-hash-v2"));

        // Build predicateData per ADR-002:
        // predicateData[0] = 0x01 (result=true)
        // predicateData[1:] = abi.encode(predicateType, result, checkedAt, expiresAt, vcType, contentHash, extraData)
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

        // Build chain-bound digest per ADR-002 §D
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

        // 1. Add deployer as whitelisted signer (if not already)
        verifier.addSigner(deployer);
        console.log("Added deployer as signer");

        // 2. Submit the attestation
        verifier.submitAttestation(attestationId, subjectDID, predicateData, signature);
        console.log("Attestation submitted successfully");
        console.logBytes32(attestationId);

        vm.stopBroadcast();
    }
}
