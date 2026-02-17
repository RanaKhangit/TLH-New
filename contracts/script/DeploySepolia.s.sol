// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {DIDRegistry} from "../src/shared/DIDRegistry.sol";
import {AttestationVerifier} from "../src/shared/AttestationVerifier.sol";
import {VCHashAnchors} from "../src/shared/VCHashAnchors.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySepolia is Script {
    struct Deployment {
        address didImpl;
        address vcImpl;
        address credImpl;
        address trustAttestImpl;
        address attestImpl;
        address didProxy;
        address vcProxy;
        address credProxy;
        address trustAttestProxy;
        address attestProxy;
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

        console2.log("NETWORK: sepolia (11155111)");
        console2.log("DEPLOYER:", deployer);
        console2.log("ADMIN:", admin);
        console2.log("BOOTSTRAP_ROLES:", bootstrapRoles);
        console2.log("ATTESTATION_SIGNER:", signer);

        console2.log("DIDRegistry impl:", dep.didImpl);
        console2.log("DIDRegistry proxy:", dep.didProxy);
        console2.log("VCHashAnchors impl:", dep.vcImpl);
        console2.log("VCHashAnchors proxy:", dep.vcProxy);
        console2.log("CredentialRegistry impl:", dep.credImpl);
        console2.log("CredentialRegistry proxy:", dep.credProxy);
        console2.log("TrustAttestationVerifier impl:", dep.trustAttestImpl);
        console2.log("TrustAttestationVerifier proxy:", dep.trustAttestProxy);
        console2.log("AttestationVerifier impl:", dep.attestImpl);
        console2.log("AttestationVerifier proxy:", dep.attestProxy);
    }

    function _deployContracts(uint256 deployerKey, address admin) internal returns (Deployment memory dep) {
        vm.startBroadcast(deployerKey);

        DIDRegistry didImpl = new DIDRegistry();
        VCHashAnchors vcImpl = new VCHashAnchors();
        CredentialRegistry credImpl = new CredentialRegistry();
        TrustAttestationVerifier trustAttestImpl = new TrustAttestationVerifier();
        AttestationVerifier attestImpl = new AttestationVerifier();

        ERC1967Proxy didProxy =
            new ERC1967Proxy(address(didImpl), abi.encodeWithSignature("initialize(address)", admin));
        ERC1967Proxy vcProxy = new ERC1967Proxy(address(vcImpl), abi.encodeWithSignature("initialize(address)", admin));
        ERC1967Proxy credProxy =
            new ERC1967Proxy(address(credImpl), abi.encodeWithSignature("initialize(address)", admin));

        ERC1967Proxy trustAttestProxy = new ERC1967Proxy(
            address(trustAttestImpl), abi.encodeWithSignature("initialize(address,address)", admin, address(credProxy))
        );

        ERC1967Proxy attestProxy = new ERC1967Proxy(
            address(attestImpl),
            abi.encodeWithSignature("initialize(address,address,address)", admin, address(didProxy), address(vcProxy))
        );

        vm.stopBroadcast();

        dep = Deployment({
            didImpl: address(didImpl),
            vcImpl: address(vcImpl),
            credImpl: address(credImpl),
            trustAttestImpl: address(trustAttestImpl),
            attestImpl: address(attestImpl),
            didProxy: address(didProxy),
            vcProxy: address(vcProxy),
            credProxy: address(credProxy),
            trustAttestProxy: address(trustAttestProxy),
            attestProxy: address(attestProxy)
        });
    }

    function _bootstrap(Deployment memory dep, address signer) internal {
        DIDRegistry did = DIDRegistry(dep.didProxy);
        VCHashAnchors vc = VCHashAnchors(dep.vcProxy);
        CredentialRegistry cred = CredentialRegistry(dep.credProxy);
        AttestationVerifier attest = AttestationVerifier(dep.attestProxy);
        TrustAttestationVerifier trustAttest = TrustAttestationVerifier(dep.trustAttestProxy);

        did.grantRole(did.REGISTRAR_ROLE(), dep.attestProxy);
        vc.grantRole(vc.ANCHOR_WRITER_ROLE(), dep.attestProxy);
        cred.grantVerifier(dep.trustAttestProxy);

        if (signer != address(0)) {
            attest.addSigner(signer);
            trustAttest.addSigner(signer);
        } else {
            console2.log("SIGNER SKIPPED: ATTESTATION_SIGNER not provided");
        }
    }
}
