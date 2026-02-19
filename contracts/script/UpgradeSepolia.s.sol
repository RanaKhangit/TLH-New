// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {AttestationVerifier} from "../src/shared/AttestationVerifier.sol";
import {DIDRegistry} from "../src/shared/DIDRegistry.sol";
import {VCHashAnchors} from "../src/shared/VCHashAnchors.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title UpgradeSepolia — Deploy new implementations and upgrade all proxies on Sepolia
/// @notice Upgrades contracts to include M-12 (abi.encode digest), L-2 (isSigner), L-3, H-7, H-8, H-9, etc.
contract UpgradeSepolia is Script {
    // Proxy addresses from deployment-manifest.sepolia.json
    address constant ATTEST_PROXY = 0xCE863E465f21Df87Ad9F0A2af838Fac1750F08d2;
    address constant DID_PROXY = 0x6C6fA7f93860F16A1dFDD60Ca3B83b703C597a0A;
    address constant VC_PROXY = 0x95D02Ae28D6fa86f67F121bA36d9cbD363AaFc68;
    address constant CRED_PROXY = 0xaE4B71776Fab8E431ceE4874Ad3a2a97588D89FB;
    address constant TRUST_ATTEST_PROXY = 0x2Ad7540B14585ebFB3c86604d1927b40e2eFa5db;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        console2.log("Deployer / Admin:", deployer);

        vm.startBroadcast(deployerKey);

        // Deploy new implementations
        AttestationVerifier newAttest = new AttestationVerifier();
        console2.log("New AttestationVerifier impl:", address(newAttest));

        DIDRegistry newDID = new DIDRegistry();
        console2.log("New DIDRegistry impl:", address(newDID));

        VCHashAnchors newVC = new VCHashAnchors();
        console2.log("New VCHashAnchors impl:", address(newVC));

        CredentialRegistry newCred = new CredentialRegistry();
        console2.log("New CredentialRegistry impl:", address(newCred));

        TrustAttestationVerifier newTrustAttest = new TrustAttestationVerifier();
        console2.log("New TrustAttestationVerifier impl:", address(newTrustAttest));

        // Upgrade each proxy (UUPS — only UPGRADER_ROLE can call)
        UUPSUpgradeable(ATTEST_PROXY).upgradeToAndCall(address(newAttest), "");
        console2.log("AttestationVerifier upgraded");

        UUPSUpgradeable(DID_PROXY).upgradeToAndCall(address(newDID), "");
        console2.log("DIDRegistry upgraded");

        UUPSUpgradeable(VC_PROXY).upgradeToAndCall(address(newVC), "");
        console2.log("VCHashAnchors upgraded");

        UUPSUpgradeable(CRED_PROXY).upgradeToAndCall(address(newCred), "");
        console2.log("CredentialRegistry upgraded");

        UUPSUpgradeable(TRUST_ATTEST_PROXY).upgradeToAndCall(address(newTrustAttest), "");
        console2.log("TrustAttestationVerifier upgraded");

        vm.stopBroadcast();

        console2.log("All Sepolia proxies upgraded successfully");
    }
}
