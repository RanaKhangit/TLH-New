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
///      Abstract — not directly deployable. Concrete children MUST include:
///      `constructor() { _disableInitializers(); }`
abstract contract BaseAttestationVerifier is Initializable, AccessControlUpgradeable {
    using MessageHashUtils for bytes32;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ADMIN_ROLE = keccak256("SIGNER_ADMIN_ROLE");

    // -------------------------
    // Custom errors
    // -------------------------
    error InvalidSignature();
    error UnauthorizedSigner(address recovered);
    error DuplicateAttestation(bytes32 attestationId);
    error EmptyPredicateData();

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
    function __BaseAttestationVerifier_init(address admin) internal onlyInitializing {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(SIGNER_ADMIN_ROLE, admin);
    }

    // -------------------------
    // Signer management
    // -------------------------
    function addSigner(address signer) external onlyRole(SIGNER_ADMIN_ROLE) {
        signerWhitelist[signer] = true;
        emit SignerAdded(signer);
    }

    function removeSigner(address signer) external onlyRole(SIGNER_ADMIN_ROLE) {
        signerWhitelist[signer] = false;
        emit SignerRemoved(signer);
    }

    // -------------------------
    // Core verify + store
    // -------------------------
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

        // F-02: Chain-bound digest includes block.chainid and contract address to prevent cross-chain replay
        bytes32 digest = keccak256(
                abi.encodePacked(block.chainid, address(this), attestationId, subjectDID, keccak256(predicateData))
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
