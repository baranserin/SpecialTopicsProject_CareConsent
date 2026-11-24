// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IRecordRegistry
/// @notice Interface for anchoring immutable ciphertext digests of encrypted off-chain health record versions.
interface IRecordRegistry {
    /// @notice On-chain commitment metadata for a single health record version.
    /// @dev Plaintext clinical fields, keys, and raw IPFS CIDs are never stored on chain.
    struct RecordVersion {
        address owner;
        bytes32 ciphertextDigest;
        bytes32 replacesVersionId;
        uint64 registeredAt;
        bool retired;
    }

    error InvalidVersionId();
    error InvalidCiphertextDigest();
    error VersionAlreadyRegistered(bytes32 versionId);
    error ReplacedVersionNotFound(bytes32 replacesVersionId);
    error VersionNotFound(bytes32 versionId);
    error NotVersionOwner(bytes32 versionId, address caller);
    error VersionAlreadyRetired(bytes32 versionId);

    /// @notice Emitted when a patient registers a new encrypted health record version commitment.
    event VersionRegistered(
        bytes32 indexed versionId,
        address indexed owner,
        bytes32 ciphertextDigest,
        bytes32 indexed replacesVersionId,
        uint64 registeredAt
    );

    /// @notice Emitted when a patient retires a previously registered record version.
    event VersionRetired(bytes32 indexed versionId, address indexed owner, uint64 retiredAt);

    /// @notice Registers an opaque record version identifier and the SHA-256 digest of its encrypted envelope.
    /// @param versionId Opaque off-chain identifier for the record version (must be non-zero).
    /// @param ciphertextDigest SHA-256 digest of the AES-256-GCM encrypted envelope bytes (must be non-zero).
    /// @param replacesVersionId Optional prior version identifier superseded by this version, or bytes32(0).
    function registerVersion(bytes32 versionId, bytes32 ciphertextDigest, bytes32 replacesVersionId) external;

    /// @notice Marks an owned version as retired without mutating its stored ciphertext digest or lineage.
    /// @param versionId Identifier of the version to retire.
    function retireVersion(bytes32 versionId) external;

    /// @notice Returns the full metadata record for a registered version.
    /// @param versionId Identifier of the version to query.
    function getVersion(bytes32 versionId) external view returns (RecordVersion memory);

    /// @notice Returns true if a version identifier has been registered.
    /// @param versionId Identifier to check.
    function versionExists(bytes32 versionId) external view returns (bool);

    /// @notice Returns the owner address of a registered version, or address(0) if unregistered.
    /// @param versionId Identifier to query.
    function ownerOf(bytes32 versionId) external view returns (address);

    /// @notice Verifies whether a candidate ciphertext digest matches the anchored commitment for a version.
    /// @param versionId Identifier of the registered version.
    /// @param ciphertextDigest Candidate SHA-256 digest to verify.
    function verifyDigest(bytes32 versionId, bytes32 ciphertextDigest) external view returns (bool);
}
