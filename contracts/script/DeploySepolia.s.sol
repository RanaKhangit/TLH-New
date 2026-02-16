// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

// Core implementations (UUPS)
import {DIDRegistry} from "../src/shared/DIDRegistry.sol";
import {AttestationVerifier} from "../src/shared/AttestationVerifier.sol";
import {VCHashAnchors} from "../src/shared/VCHashAnchors.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";

// ERC1967 proxy (nested dependency present in your lib tree)
import {ERC1967Proxy} from
  "openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySepolia is Script {
    function run() external {
        string memory pk = vm.envString("DEPLOYER_PRIVATE_KEY");
        // accept either "0x..." or "..."
        uint256 deployerKey = vm.parseUint(pk);
        address deployer = vm.addr(deployerKey);

        address admin = vm.envAddress("ADMIN_ADDRESS");
        require(admin != address(0), "ADMIN_ADDRESS missing");

        vm.startBroadcast(deployerKey);

        // 1) Deploy implementations
        DIDRegistry didImpl = new DIDRegistry();
        VCHashAnchors vcImpl = new VCHashAnchors();
        CredentialRegistry credImpl = new CredentialRegistry();
        TrustAttestationVerifier trustAttestImpl = new TrustAttestationVerifier();
        AttestationVerifier attestImpl = new AttestationVerifier();

        // 2) Initializer calldata (matches your signatures)
        bytes memory didInit = abi.encodeWithSignature("initialize(address)", admin);
        bytes memory vcInit = abi.encodeWithSignature("initialize(address)", admin);
        bytes memory credInit = abi.encodeWithSignature("initialize(address)", admin);

        // 3) Deploy proxies (wire dependencies to PROXIES)
        ERC1967Proxy didProxy = new ERC1967Proxy(address(didImpl), didInit);
        ERC1967Proxy vcProxy = new ERC1967Proxy(address(vcImpl), vcInit);
        ERC1967Proxy credProxy = new ERC1967Proxy(address(credImpl), credInit);

        bytes memory trustAttestInit =
            abi.encodeWithSignature("initialize(address,address)", admin, address(credProxy));
        ERC1967Proxy trustAttestProxy =
            new ERC1967Proxy(address(trustAttestImpl), trustAttestInit);

        bytes memory attestInit =
            abi.encodeWithSignature(
                "initialize(address,address,address)",
                admin,
                address(didProxy),
                address(vcProxy)
            );
        ERC1967Proxy attestProxy =
            new ERC1967Proxy(address(attestImpl), attestInit);

        vm.stopBroadcast();

        // 4) Print for manifest
        console2.log("NETWORK: sepolia (11155111)");
        console2.log("DEPLOYER:", deployer);
        console2.log("ADMIN:", admin);

        console2.log("DIDRegistry impl:", address(didImpl));
        console2.log("DIDRegistry proxy:", address(didProxy));

        console2.log("VCHashAnchors impl:", address(vcImpl));
        console2.log("VCHashAnchors proxy:", address(vcProxy));

        console2.log("CredentialRegistry impl:", address(credImpl));
        console2.log("CredentialRegistry proxy:", address(credProxy));

        console2.log("TrustAttestationVerifier impl:", address(trustAttestImpl));
        console2.log("TrustAttestationVerifier proxy:", address(trustAttestProxy));

        console2.log("AttestationVerifier impl:", address(attestImpl));
        console2.log("AttestationVerifier proxy:", address(attestProxy));
    }
}
