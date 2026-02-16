// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {TLHCCIPSender} from "../src/ccip/TLHCCIPSender.sol";
import {TLHCCIPReceiver} from "../src/ccip/TLHCCIPReceiver.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title DeployCCIP
/// @notice Deploys TLHCCIPSender or TLHCCIPReceiver depending on DEPLOY_MODE env var.
///
///   DEPLOY_MODE=sender  → deploys TLHCCIPSender  (Trust chain / Arbitrum Sepolia)
///   DEPLOY_MODE=receiver → deploys TLHCCIPReceiver (Anchor chain / Ethereum Sepolia)
///
/// Required env vars:
///   DEPLOYER_PRIVATE_KEY  — hex-encoded deployer private key
///   ADMIN_ADDRESS         — admin address for role grants
///   CCIP_ROUTER           — CCIP Router address on target chain
///   CREDENTIAL_REGISTRY   — CredentialRegistry proxy address on target chain
///   DEPLOY_MODE           — "sender" or "receiver"
///
/// Post-deploy manual steps:
///   - Sender: call configureDestination(destChainSelector, receiverAddress, true)
///   - Receiver: call configureSourceChain(...) + configureSender(...)
///   - Receiver: grant VERIFIER_ROLE on CredentialRegistry to receiver proxy
contract DeployCCIP is Script {
    function run() external {
        string memory pk = vm.envString("DEPLOYER_PRIVATE_KEY");
        uint256 deployerKey = vm.parseUint(pk);
        address deployer = vm.addr(deployerKey);

        address admin = vm.envAddress("ADMIN_ADDRESS");
        address ccipRouter = vm.envAddress("CCIP_ROUTER");
        address credentialRegistry = vm.envAddress("CREDENTIAL_REGISTRY");
        string memory mode = vm.envString("DEPLOY_MODE");

        require(admin != address(0), "ADMIN_ADDRESS missing");
        require(ccipRouter != address(0), "CCIP_ROUTER missing");
        require(credentialRegistry != address(0), "CREDENTIAL_REGISTRY missing");

        console2.log("DEPLOYER:", deployer);
        console2.log("ADMIN:", admin);
        console2.log("CCIP_ROUTER:", ccipRouter);
        console2.log("CREDENTIAL_REGISTRY:", credentialRegistry);
        console2.log("DEPLOY_MODE:", mode);

        if (keccak256(bytes(mode)) == keccak256("sender")) {
            _deploySender(deployerKey, admin, ccipRouter, credentialRegistry);
        } else if (keccak256(bytes(mode)) == keccak256("receiver")) {
            _deployReceiver(deployerKey, admin, ccipRouter, credentialRegistry);
        } else {
            revert("DEPLOY_MODE must be 'sender' or 'receiver'");
        }
    }

    function _deploySender(
        uint256 deployerKey,
        address admin,
        address ccipRouter,
        address credentialRegistry
    ) internal {
        vm.startBroadcast(deployerKey);

        TLHCCIPSender impl = new TLHCCIPSender();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPSender.initialize.selector, admin, ccipRouter, credentialRegistry)
        );

        vm.stopBroadcast();

        console2.log("TLHCCIPSender impl:", address(impl));
        console2.log("TLHCCIPSender proxy:", address(proxy));
        console2.log("");
        console2.log("Next steps:");
        console2.log("  1. sender.configureDestination(destChainSelector, receiverProxy, true)");
        console2.log("  2. sender.grantRole(SENDER_ROLE, authorizedSender)");
    }

    function _deployReceiver(
        uint256 deployerKey,
        address admin,
        address ccipRouter,
        address credentialRegistry
    ) internal {
        vm.startBroadcast(deployerKey);

        TLHCCIPReceiver impl = new TLHCCIPReceiver();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeWithSelector(TLHCCIPReceiver.initialize.selector, admin, ccipRouter, credentialRegistry)
        );

        vm.stopBroadcast();

        console2.log("TLHCCIPReceiver impl:", address(impl));
        console2.log("TLHCCIPReceiver proxy:", address(proxy));
        console2.log("");
        console2.log("Next steps:");
        console2.log("  1. receiver.configureSourceChain(sourceChainSelector, true)");
        console2.log("  2. receiver.configureSender(sourceChainSelector, senderProxy, true)");
        console2.log("  3. credentialRegistry.grantVerifier(receiverProxy)");
    }
}
