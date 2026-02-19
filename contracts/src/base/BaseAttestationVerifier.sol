// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title BaseAttestationVerifier
/// @notice Shared signature verification + replay protection used by both verifiers.
/// @dev UUPS is implemented in child contracts; this base provides shared storage and logic.
///      Success-path events only; all invalid submissions revert with custom errors.
abstract contract BaseAttestationVerifier is Initializable, AccessControlUpgradeable {
    using MessageHashUtils for bytes32;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ADMIN_ROLE = keccak256("SIGNER_ADMIN_ROLE");

    /// @dev Domain tag included in signature digest per ADR-002 §A.
    string internal constant DOMAIN = "TLH_ATTESTATION_V1";

    // -------------------------
    // Custom errors
    // -------------------------
    error InvalidSignature();
    error UnauthorizedSigner(address recovered);
    error DuplicateAttestation(bytes32 attestationId);
    error EmptyPredicateData();
    error ResultMismatch();
    error ExpiredAttestation(uint256 expiresAt, uint256 nowTs);
    error InvalidAdmin(address admin);
    error InvalidSigner(address signer);

    // -------------------------
    // Events (success-path only)
    // -------------------------
    event AttestationSubmitted(
        bytes32 indexed attestationId, bytes32 indexed subjectDID, bool result, uint256 timestamp
    );
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);

    // -------------------------
    // Storage
    // -------------------------
    mapping(address => bool) internal signerWhitelist;
    mapping(bytes32 => bool) internal attestationUsed;

    struct Attestation {
        bytes32 subjectDID;
        bytes32 predicateHash;
        bool result;
        uint256 timestamp;
    }

    mapping(bytes32 => Attestation) internal attestations;

    // -------------------------
    // Init
    // -------------------------
    /// @param admin Address granted DEFAULT_ADMIN_ROLE, ADMIN_ROLE, and SIGNER_ADMIN_ROLE.
    function __BaseAttestationVerifier_init(address admin) internal onlyInitializing {
        if (admin == address(0)) revert InvalidAdmin(admin);

        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(SIGNER_ADMIN_ROLE, admin);
    }

    // -------------------------
    // Signer management
    // -------------------------
    /// @notice Check whether an address is a whitelisted signer.
    function isSigner(address addr) external view returns (bool) {
        return signerWhitelist[addr];
    }

    /// @notice Whitelist a signer address for attestation verification.
    /// @param signer Address to add to the signer whitelist.
    function addSigner(address signer) external onlyRole(SIGNER_ADMIN_ROLE) {
        if (signer == address(0)) revert InvalidSigner(signer);
        if (signerWhitelist[signer]) return; // L-3: idempotent — no-op if already added
        signerWhitelist[signer] = true;
        emit SignerAdded(signer);
    }

    /// @notice Remove a signer address from the whitelist.
    /// @param signer Address to remove from the signer whitelist.
    function removeSigner(address signer) external onlyRole(SIGNER_ADMIN_ROLE) {
        if (signer == address(0)) revert InvalidSigner(signer);
        if (!signerWhitelist[signer]) return; // L-3: idempotent — no-op if already removed
        signerWhitelist[signer] = false;
        emit SignerRemoved(signer);
    }

    // -------------------------
    // Core verify + store
    // -------------------------
    /// @dev Verify signature, enforce replay/result/expiry rules, then store attestation.
    /// @param attestationId Unique attestation identifier (must not have been used before).
    /// @param subjectDID DID of the attestation subject.
    /// @param predicateData ABI-encoded predicate payload; first byte is result flag.
    /// @param signature ECDSA signature over the chain-bound digest.
    /// @return result Decoded boolean result from predicateData[0].
    function _verifyAndStore(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bytes calldata signature
    ) internal returns (bool result) {
        if (attestationUsed[attestationId]) revert DuplicateAttestation(attestationId);
        if (predicateData.length == 0) revert EmptyPredicateData();

        // Convention: predicateData[0] is 0x00/0x01 representing result.
        result = predicateData[0] == bytes1(0x01);

        // ADR-002 §C: decode ABI-encoded payload after the result byte.
        (, bool abiResult,, uint256 expiresAt,,,) =
            abi.decode(predicateData[1:], (bytes32, bool, uint256, uint256, bytes32, bytes32, bytes));
        if (result != abiResult) revert ResultMismatch();
        if (result && expiresAt != 0 && block.timestamp > expiresAt) {
            revert ExpiredAttestation(expiresAt, block.timestamp);
        }

        // Chain-bound digest per ADR-002 §D: domain + chainid + contract address + payload.
        // M-12: Use abi.encode (not encodePacked) to prevent hash collision risk.
        bytes32 digest = keccak256(
                abi.encode(
                    DOMAIN, block.chainid, address(this), attestationId, subjectDID, keccak256(predicateData)
                )
            ).toEthSignedMessageHash();

        address recovered = ECDSA.recover(digest, signature);
        if (recovered == address(0)) revert InvalidSignature();
        if (!signerWhitelist[recovered]) revert UnauthorizedSigner(recovered);

        attestationUsed[attestationId] = true;
        attestations[attestationId] = Attestation({
            subjectDID: subjectDID, predicateHash: keccak256(predicateData), result: result, timestamp: block.timestamp
        });

        emit AttestationSubmitted(attestationId, subjectDID, result, block.timestamp);

        _onAttestationVerified(attestationId, subjectDID, predicateData, result);
    }

    /// @notice Hook executed only after a successful verification + store.
    function _onAttestationVerified(
        bytes32 attestationId,
        bytes32 subjectDID,
        bytes calldata predicateData,
        bool result
    ) internal virtual;

    uint256[50] private __gap;
}
