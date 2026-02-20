// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title UpgradePrivateChain — Deploy new implementations and upgrade trust proxies on private chain
/// @notice Upgrades CredentialRegistry and TrustAttestationVerifier to include security fixes:
///         M-12 (abi.encode digest), L-2 (isSigner), L-3 (idempotent guards), H-7 (revocation guards),
///         H-8 (pagination), CredentialRegistryUpdated event, etc.
contract UpgradePrivateChain is Script {
    // Proxy addresses from deployment-manifest.private-chain.json
    address constant CRED_PROXY = 0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE;
    address constant TRUST_ATTEST_PROXY = 0x68B1D87F95878fE05B998F19b66F4baba5De1aed;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        console2.log("Deployer / Admin:", deployer);

        vm.startBroadcast(deployerKey);

        // Deploy new implementations
        CredentialRegistry newCred = new CredentialRegistry();
        console2.log("New CredentialRegistry impl:", address(newCred));

        TrustAttestationVerifier newTrustAttest = new TrustAttestationVerifier();
        console2.log("New TrustAttestationVerifier impl:", address(newTrustAttest));

        // Upgrade each proxy (UUPS — only UPGRADER_ROLE can call)
        UUPSUpgradeable(CRED_PROXY).upgradeToAndCall(address(newCred), "");
        console2.log("CredentialRegistry upgraded");

        UUPSUpgradeable(TRUST_ATTEST_PROXY).upgradeToAndCall(address(newTrustAttest), "");
        console2.log("TrustAttestationVerifier upgraded");

        vm.stopBroadcast();

        console2.log("All private chain proxies upgraded successfully");
    }
}
