// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import {DIDRegistry} from "../src/shared/DIDRegistry.sol";
import {VCHashAnchors} from "../src/shared/VCHashAnchors.sol";
import {CredentialRegistry} from "../src/trust/CredentialRegistry.sol";
import {AttestationVerifier} from "../src/shared/AttestationVerifier.sol";
import {TrustAttestationVerifier} from "../src/trust/TrustAttestationVerifier.sol";

contract TransferRolesToMultisig is Script {
    function run() external {
        string memory adminPk = vm.envString("ADMIN_PRIVATE_KEY");
        uint256 adminKey = vm.parseUint(adminPk);
        address currentAdmin = vm.addr(adminKey);

        address multisig = vm.envAddress("MULTISIG_ADDRESS");
        require(multisig != address(0), "MULTISIG_ADDRESS missing");

        address didProxy = vm.envOr("DID_REGISTRY_PROXY", address(0));
        address vcProxy = vm.envOr("VC_HASH_ANCHORS_PROXY", address(0));
        address credProxy = vm.envOr("CREDENTIAL_REGISTRY_PROXY", address(0));
        address avProxy = vm.envOr("ATTESTATION_VERIFIER_PROXY", address(0));
        address tavProxy = vm.envOr("TRUST_ATTESTATION_VERIFIER_PROXY", address(0));

        bool revokeOldAdmin = vm.envOr("REVOKE_OLD_ADMIN", false);

        vm.startBroadcast(adminKey);

        bool didMigrated = _migrateDIDRegistryIfPresent(didProxy, currentAdmin, multisig, revokeOldAdmin);
        bool vcMigrated = _migrateVCHashAnchorsIfPresent(vcProxy, currentAdmin, multisig, revokeOldAdmin);
        bool credMigrated = _migrateCredentialRegistryIfPresent(credProxy, currentAdmin, multisig, revokeOldAdmin);
        bool avMigrated = _migrateAttestationVerifierIfPresent(avProxy, currentAdmin, multisig, revokeOldAdmin);
        bool tavMigrated = _migrateTrustAttestationVerifierIfPresent(tavProxy, currentAdmin, multisig, revokeOldAdmin);

        vm.stopBroadcast();

        require(didMigrated || vcMigrated || credMigrated || avMigrated || tavMigrated, "No valid proxy targets");
        console2.log("Roles migrated to multisig:", multisig);
        console2.log("Revoked old admin roles:", revokeOldAdmin);
    }

    function _migrateDIDRegistryIfPresent(address proxy, address oldAdmin, address multisig, bool revokeOldAdmin)
        internal
        returns (bool)
    {
        if (!_isContract(proxy)) return false;
        _migrateDIDRegistry(DIDRegistry(proxy), oldAdmin, multisig, revokeOldAdmin);
        return true;
    }

    function _migrateVCHashAnchorsIfPresent(address proxy, address oldAdmin, address multisig, bool revokeOldAdmin)
        internal
        returns (bool)
    {
        if (!_isContract(proxy)) return false;
        _migrateVCHashAnchors(VCHashAnchors(proxy), oldAdmin, multisig, revokeOldAdmin);
        return true;
    }

    function _migrateCredentialRegistryIfPresent(address proxy, address oldAdmin, address multisig, bool revokeOldAdmin)
        internal
        returns (bool)
    {
        if (!_isContract(proxy)) return false;
        _migrateCredentialRegistry(CredentialRegistry(proxy), oldAdmin, multisig, revokeOldAdmin);
        return true;
    }

    function _migrateAttestationVerifierIfPresent(address proxy, address oldAdmin, address multisig, bool revokeOldAdmin)
        internal
        returns (bool)
    {
        if (!_isContract(proxy)) return false;
        _migrateAttestationVerifier(AttestationVerifier(proxy), oldAdmin, multisig, revokeOldAdmin);
        return true;
    }

    function _migrateTrustAttestationVerifierIfPresent(
        address proxy,
        address oldAdmin,
        address multisig,
        bool revokeOldAdmin
    ) internal returns (bool) {
        if (!_isContract(proxy)) return false;
        _migrateTrustAttestationVerifier(TrustAttestationVerifier(proxy), oldAdmin, multisig, revokeOldAdmin);
        return true;
    }

    function _isContract(address a) internal view returns (bool) {
        return a != address(0) && a.code.length > 0;
    }

    function _migrateDIDRegistry(DIDRegistry c, address oldAdmin, address multisig, bool revokeOldAdmin) internal {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), multisig);
        c.grantRole(c.UPGRADER_ROLE(), multisig);
        if (revokeOldAdmin) {
            c.revokeRole(c.UPGRADER_ROLE(), oldAdmin);
            c.revokeRole(c.DEFAULT_ADMIN_ROLE(), oldAdmin);
        }
    }

    function _migrateVCHashAnchors(VCHashAnchors c, address oldAdmin, address multisig, bool revokeOldAdmin) internal {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), multisig);
        c.grantRole(c.ADMIN_ROLE(), multisig);
        c.grantRole(c.UPGRADER_ROLE(), multisig);
        if (revokeOldAdmin) {
            c.revokeRole(c.UPGRADER_ROLE(), oldAdmin);
            c.revokeRole(c.ADMIN_ROLE(), oldAdmin);
            c.revokeRole(c.DEFAULT_ADMIN_ROLE(), oldAdmin);
        }
    }

    function _migrateCredentialRegistry(CredentialRegistry c, address oldAdmin, address multisig, bool revokeOldAdmin)
        internal
    {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), multisig);
        c.grantRole(c.ADMIN_ROLE(), multisig);
        c.grantRole(c.UPGRADER_ROLE(), multisig);
        if (revokeOldAdmin) {
            c.revokeRole(c.UPGRADER_ROLE(), oldAdmin);
            c.revokeRole(c.ADMIN_ROLE(), oldAdmin);
            c.revokeRole(c.DEFAULT_ADMIN_ROLE(), oldAdmin);
        }
    }

    function _migrateAttestationVerifier(AttestationVerifier c, address oldAdmin, address multisig, bool revokeOldAdmin)
        internal
    {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), multisig);
        c.grantRole(c.ADMIN_ROLE(), multisig);
        c.grantRole(c.SIGNER_ADMIN_ROLE(), multisig);
        c.grantRole(c.UPGRADER_ROLE(), multisig);
        if (revokeOldAdmin) {
            c.revokeRole(c.UPGRADER_ROLE(), oldAdmin);
            c.revokeRole(c.SIGNER_ADMIN_ROLE(), oldAdmin);
            c.revokeRole(c.ADMIN_ROLE(), oldAdmin);
            c.revokeRole(c.DEFAULT_ADMIN_ROLE(), oldAdmin);
        }
    }

    function _migrateTrustAttestationVerifier(
        TrustAttestationVerifier c,
        address oldAdmin,
        address multisig,
        bool revokeOldAdmin
    ) internal {
        c.grantRole(c.DEFAULT_ADMIN_ROLE(), multisig);
        c.grantRole(c.ADMIN_ROLE(), multisig);
        c.grantRole(c.SIGNER_ADMIN_ROLE(), multisig);
        c.grantRole(c.UPGRADER_ROLE(), multisig);
        if (revokeOldAdmin) {
            c.revokeRole(c.UPGRADER_ROLE(), oldAdmin);
            c.revokeRole(c.SIGNER_ADMIN_ROLE(), oldAdmin);
            c.revokeRole(c.ADMIN_ROLE(), oldAdmin);
            c.revokeRole(c.DEFAULT_ADMIN_ROLE(), oldAdmin);
        }
    }
}
