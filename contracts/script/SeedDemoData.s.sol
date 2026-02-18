// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {DIDRegistry} from "../src/shared/DIDRegistry.sol";
import {VCHashAnchors} from "../src/shared/VCHashAnchors.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";

/// @title SeedDemoData — Register demo DIDs, anchors, and credentials on Sepolia
contract SeedDemoData is Script {
    function run() external {
        // --- Proxy addresses from deployment-manifest.sepolia.json ---
        DIDRegistry did = DIDRegistry(0x6C6fA7f93860F16A1dFDD60Ca3B83b703C597a0A);
        VCHashAnchors vc = VCHashAnchors(0x95D02Ae28D6fa86f67F121bA36d9cbD363AaFc68);
        CredentialRegistry cred = CredentialRegistry(0xaE4B71776Fab8E431ceE4874Ad3a2a97588D89FB);

        vm.startBroadcast();

        // ---- 1. Register two DIDs ----
        bytes32 clinicianDID = keccak256(abi.encodePacked("did:tlh:clinician-789"));
        bytes32 patientDID = keccak256(abi.encodePacked("did:tlh:patient-123"));

        did.registerDID(clinicianDID, msg.sender);
        console.log("Registered did:tlh:clinician-789");

        did.registerDID(patientDID, msg.sender);
        console.log("Registered did:tlh:patient-123");

        // ---- 2. Grant ANCHOR_WRITER_ROLE to deployer, then anchor a VC hash ----
        bytes32 ANCHOR_WRITER_ROLE = keccak256("ANCHOR_WRITER_ROLE");
        vc.grantRole(ANCHOR_WRITER_ROLE, msg.sender);

        bytes32 vcType = keccak256(abi.encodePacked("GMC_REGISTRATION"));
        bytes32 contentHash = keccak256(abi.encodePacked("demo-vc-content-hash-v1"));
        vc.anchorHash(clinicianDID, vcType, contentHash);
        console.log("Anchored VC hash for clinician");

        // ---- 3. Grant VERIFIER_ROLE to deployer, then write a credential ----
        cred.grantVerifier(msg.sender);

        bytes32 predType = keccak256(abi.encodePacked("GMC_REGISTERED"));
        cred.writeCredential(
            clinicianDID,
            predType,
            true,                    // valid
            block.timestamp + 365 days, // expires in 1 year
            keccak256("demo-attestation-id")
        );
        console.log("Wrote credential for clinician");

        vm.stopBroadcast();
    }
}
