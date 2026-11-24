// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRecordRegistry} from "./interfaces/IRecordRegistry.sol";

/// @title RecordRegistry
/// @notice Stores immutable integrity commitments for patient-owned encrypted health record versions.
/// @dev Only opaque identifiers and SHA-256 ciphertext digests are anchored on chain.
contract RecordRegistry is IRecordRegistry {
    mapping(bytes32 => RecordVersion) private _versions;

    /// @inheritdoc IRecordRegistry
    function registerVersion(bytes32 versionId, bytes32 ciphertextDigest, bytes32 replacesVersionId) external {
        if (versionId == bytes32(0)) {
            revert InvalidVersionId();
        }
        if (ciphertextDigest == bytes32(0)) {
            revert InvalidCiphertextDigest();
        }
        if (_versions[versionId].owner != address(0)) {
            revert VersionAlreadyRegistered(versionId);
        }

        if (replacesVersionId != bytes32(0)) {
            address previousOwner = _versions[replacesVersionId].owner;
            if (previousOwner == address(0)) {
                revert ReplacedVersionNotFound(replacesVersionId);
            }
            if (previousOwner != msg.sender) {
                revert NotVersionOwner(replacesVersionId, msg.sender);
            }
        }

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 registeredAt = uint64(block.timestamp);
        _versions[versionId] = RecordVersion({
            owner: msg.sender,
            ciphertextDigest: ciphertextDigest,
            replacesVersionId: replacesVersionId,
            registeredAt: registeredAt,
            retired: false
        });

        emit VersionRegistered(versionId, msg.sender, ciphertextDigest, replacesVersionId, registeredAt);
    }

    /// @inheritdoc IRecordRegistry
    function retireVersion(bytes32 versionId) external {
        RecordVersion storage record = _versions[versionId];
        if (record.owner == address(0)) {
            revert VersionNotFound(versionId);
        }
        if (record.owner != msg.sender) {
            revert NotVersionOwner(versionId, msg.sender);
        }
        if (record.retired) {
            revert VersionAlreadyRetired(versionId);
        }

        record.retired = true;
        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        emit VersionRetired(versionId, msg.sender, uint64(block.timestamp));
    }

    /// @inheritdoc IRecordRegistry
    function getVersion(bytes32 versionId) external view returns (RecordVersion memory) {
        RecordVersion memory record = _versions[versionId];
        if (record.owner == address(0)) {
            revert VersionNotFound(versionId);
        }
        return record;
    }

    /// @inheritdoc IRecordRegistry
    function versionExists(bytes32 versionId) external view returns (bool) {
        return _versions[versionId].owner != address(0);
    }

    /// @inheritdoc IRecordRegistry
    function ownerOf(bytes32 versionId) external view returns (address) {
        return _versions[versionId].owner;
    }

    /// @inheritdoc IRecordRegistry
    function verifyDigest(bytes32 versionId, bytes32 ciphertextDigest) external view returns (bool) {
        RecordVersion storage record = _versions[versionId];
        return
            record.owner != address(0) && ciphertextDigest != bytes32(0) && record.ciphertextDigest == ciphertextDigest;
    }
}
