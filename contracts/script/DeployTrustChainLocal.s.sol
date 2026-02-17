// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployTrustChainLocal is Script {
    struct Deployment {
        address credImpl;
        address trustAttestImpl;
        address credProxy;
        address trustAttestProxy;
    }

    function run() external {
        string memory pk = vm.envString("DEPLOYER_PRIVATE_KEY");
        uint256 deployerKey = vm.parseUint(pk);
        address deployer = vm.addr(deployerKey);

        address admin = vm.envAddress("ADMIN_ADDRESS");
        require(admin != address(0), "ADMIN_ADDRESS missing");

        address signer = vm.envOr("ATTESTATION_SIGNER", address(0));
        bool bootstrapRoles = vm.envOr("BOOTSTRAP_ROLES", true);

        Deployment memory dep = _deployContracts(deployerKey, admin);

        if (bootstrapRoles) {
            if (vm.envExists("ADMIN_PRIVATE_KEY")) {
                string memory adminPk = vm.envString("ADMIN_PRIVATE_KEY");
                uint256 adminKey = vm.parseUint(adminPk);
                address adminFromKey = vm.addr(adminKey);
                require(adminFromKey == admin, "ADMIN_PRIVATE_KEY does not match ADMIN_ADDRESS");
                vm.startBroadcast(adminKey);
                _bootstrap(dep, signer);
                vm.stopBroadcast();
            } else if (deployer == admin) {
                vm.startBroadcast(deployerKey);
                _bootstrap(dep, signer);
                vm.stopBroadcast();
            } else {
                console2.log("BOOTSTRAP SKIPPED: provide ADMIN_PRIVATE_KEY or set ADMIN_ADDRESS == deployer");
            }
        }

        console2.log("NETWORK CHAINID:", block.chainid);
        console2.log("DEPLOYER:", deployer);
        console2.log("ADMIN:", admin);
        console2.log("BOOTSTRAP_ROLES:", bootstrapRoles);
        console2.log("ATTESTATION_SIGNER:", signer);

        console2.log("CredentialRegistry impl:", dep.credImpl);
        console2.log("CredentialRegistry proxy:", dep.credProxy);
        console2.log("TrustAttestationVerifier impl:", dep.trustAttestImpl);
        console2.log("TrustAttestationVerifier proxy:", dep.trustAttestProxy);
    }

    function _deployContracts(uint256 deployerKey, address admin) internal returns (Deployment memory dep) {
        vm.startBroadcast(deployerKey);

        CredentialRegistry credImpl = new CredentialRegistry();
        TrustAttestationVerifier trustAttestImpl = new TrustAttestationVerifier();

        ERC1967Proxy credProxy =
            new ERC1967Proxy(address(credImpl), abi.encodeWithSignature("initialize(address)", admin));
        ERC1967Proxy trustAttestProxy = new ERC1967Proxy(
            address(trustAttestImpl), abi.encodeWithSignature("initialize(address,address)", admin, address(credProxy))
        );

        vm.stopBroadcast();

        dep = Deployment({
            credImpl: address(credImpl),
            trustAttestImpl: address(trustAttestImpl),
            credProxy: address(credProxy),
            trustAttestProxy: address(trustAttestProxy)
        });
    }

    function _bootstrap(Deployment memory dep, address signer) internal {
        CredentialRegistry cred = CredentialRegistry(dep.credProxy);
        TrustAttestationVerifier trustAttest = TrustAttestationVerifier(dep.trustAttestProxy);

        cred.grantVerifier(dep.trustAttestProxy);

        if (signer != address(0)) {
            trustAttest.addSigner(signer);
        } else {
            console2.log("SIGNER SKIPPED: ATTESTATION_SIGNER not provided");
        }
    }
}
