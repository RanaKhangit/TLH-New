// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";

/// @title FixDEF2_AddSigner
/// @notice One-shot script to fix DEF-2: adds the EA wallet as an authorized
///         signer on the private chain TrustAttestationVerifier.
///         Run with: forge script FixDEF2_AddSigner --rpc-url $RPC_URL --broadcast
contract FixDEF2_AddSigner is Script {
    // Private chain TAV proxy (from deployment-manifest.private-chain.json)
    address constant TAV_PROXY = 0x68B1D87F95878fE05B998F19b66F4baba5De1aed;

    // EA wallet / Sepolia deployer address
    address constant EA_SIGNER = 0x3B50966A8B71f277e90e14cdC31455F6Af3977e6;

    function run() external {
        require(block.chainid == 100100, "Wrong chain: expected private chain 100100");

        uint256 adminKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        TrustAttestationVerifier tav = TrustAttestationVerifier(TAV_PROXY);

        vm.startBroadcast(adminKey);
        tav.addSigner(EA_SIGNER);
        vm.stopBroadcast();

        console2.log("DEF-2 FIX: Added signer", EA_SIGNER, "to TAV", TAV_PROXY);
    }
}
