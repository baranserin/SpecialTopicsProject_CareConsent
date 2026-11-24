// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IConsentManager} from "./interfaces/IConsentManager.sol";

/// @title ConsentManager
/// @notice Enforces patient-signed sharing grants, strict expiry boundaries, revocations, and gateway audit receipts.
/// @dev Authorizes future gateway releases only while block.timestamp < expiresAt and !revoked.
contract ConsentManager is IConsentManager {
    address public immutable admin;
    mapping(address => bool) public authorizedGateways;

    mapping(bytes32 => ConsentGrant) private _grants;
    mapping(bytes32 => ReleaseCommitment) private _releases;

    /// @notice Deploys ConsentManager with the deployer as admin and optionally allowlists an initial gateway.
    /// @param initialGateway Initial allowlisted gateway signer address, or address(0) to configure later.
    constructor(address initialGateway) {
        admin = msg.sender;
        if (initialGateway != address(0)) {
            authorizedGateways[initialGateway] = true;
            emit GatewayAuthorizationUpdated(initialGateway, true);
        }
    }

    /// @inheritdoc IConsentManager
    function setGatewayAuthorization(address gateway, bool authorized) external {
        if (msg.sender != admin) {
            revert UnauthorizedAdmin(msg.sender);
        }
        if (gateway == address(0)) {
            revert InvalidGatewayAddress();
        }
        // GatewayAuthorizationUpdated is emitted on the following line.
        // forge-lint: disable-next-line(missing-events-access-control)
        authorizedGateways[gateway] = authorized;
        emit GatewayAuthorizationUpdated(gateway, authorized);
    }

    /// @inheritdoc IConsentManager
    function grantAccess(bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment, uint64 expiresAt)
        external
    {
        if (grantId == bytes32(0)) {
            revert InvalidGrantId();
        }
        if (_grants[grantId].owner != address(0)) {
            revert GrantAlreadyExists(grantId);
        }
        if (grantee == address(0) || grantee == msg.sender) {
            revert InvalidGrantee();
        }
        if (purpose == Purpose.None) {
            revert InvalidPurpose();
        }
        if (scopeCommitment == bytes32(0)) {
            revert InvalidScopeCommitment();
        }

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 currentTime = uint64(block.timestamp);
        if (expiresAt <= currentTime) {
            revert ExpiryNotInFuture(expiresAt, currentTime);
        }

        _grants[grantId] = ConsentGrant({
            owner: msg.sender,
            grantee: grantee,
            purpose: purpose,
            scopeCommitment: scopeCommitment,
            grantedAt: currentTime,
            expiresAt: expiresAt,
            revoked: false,
            revokedAt: 0
        });

        emit GrantCreated(grantId, msg.sender, grantee, purpose, scopeCommitment, expiresAt, currentTime);
    }

    /// @inheritdoc IConsentManager
    function revokeGrant(bytes32 grantId) external {
        ConsentGrant storage grant = _grants[grantId];
        if (grant.owner == address(0)) {
            revert GrantNotFound(grantId);
        }
        if (grant.owner != msg.sender) {
            revert NotGrantOwner(grantId, msg.sender);
        }
        if (grant.revoked) {
            revert GrantAlreadyRevoked(grantId);
        }
        // Strict second-level expiry boundary (block.timestamp < expiresAt) is required by specification.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= grant.expiresAt) {
            revert GrantAlreadyExpired(grantId);
        }

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 revokedAt = uint64(block.timestamp);
        grant.revoked = true;
        grant.revokedAt = revokedAt;

        emit GrantRevoked(grantId, msg.sender, revokedAt);
    }

    /// @inheritdoc IConsentManager
    function getGrant(bytes32 grantId) external view returns (ConsentGrant memory) {
        ConsentGrant memory grant = _grants[grantId];
        if (grant.owner == address(0)) {
            revert GrantNotFound(grantId);
        }
        return grant;
    }

    /// @inheritdoc IConsentManager
    function getGrantStatus(bytes32 grantId) external view returns (GrantStatus) {
        ConsentGrant storage grant = _grants[grantId];
        if (grant.owner == address(0)) {
            return GrantStatus.NotFound;
        }
        if (grant.revoked) {
            return GrantStatus.Revoked;
        }
        // Strict second-level expiry boundary (block.timestamp < expiresAt) is required by specification.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= grant.expiresAt) {
            return GrantStatus.Expired;
        }
        return GrantStatus.Active;
    }

    /// @inheritdoc IConsentManager
    function isAccessAuthorized(bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment)
        external
        view
        returns (bool)
    {
        ConsentGrant storage grant = _grants[grantId];
        // Strict second-level expiry boundary (block.timestamp < expiresAt) is required by specification.
        // forge-lint: disable-next-line(block-timestamp)
        if (grant.owner == address(0) || grant.revoked || block.timestamp >= grant.expiresAt) {
            return false;
        }
        if (purpose == Purpose.None || scopeCommitment == bytes32(0)) {
            return false;
        }
        return grant.grantee == grantee && grant.purpose == purpose && grant.scopeCommitment == scopeCommitment;
    }

    /// @inheritdoc IConsentManager
    function recordRelease(
        bytes32 releaseId,
        bytes32 grantId,
        address grantee,
        Purpose purpose,
        bytes32 scopeCommitment,
        bytes32 receiptCommitment
    ) external {
        if (!authorizedGateways[msg.sender]) {
            revert UnauthorizedGateway(msg.sender);
        }
        if (releaseId == bytes32(0)) {
            revert InvalidReleaseId();
        }
        if (receiptCommitment == bytes32(0)) {
            revert InvalidReceiptCommitment();
        }
        if (_releases[releaseId].gateway != address(0)) {
            revert ReleaseAlreadyRecorded(releaseId);
        }

        ConsentGrant storage grant = _grants[grantId];
        if (grant.owner == address(0)) {
            revert GrantNotFound(grantId);
        }
        if (grant.revoked) {
            revert GrantIsRevoked(grantId);
        }
        // Strict second-level expiry boundary (block.timestamp < expiresAt) is required by specification.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= grant.expiresAt) {
            revert GrantIsExpired(grantId);
        }
        if (grant.grantee != grantee) {
            revert GranteeMismatch(grantId, grant.grantee, grantee);
        }
        if (grant.purpose != purpose) {
            revert PurposeMismatch(grantId, grant.purpose, purpose);
        }
        if (grant.scopeCommitment != scopeCommitment) {
            revert ScopeMismatch(grantId);
        }

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 recordedAt = uint64(block.timestamp);
        _releases[releaseId] = ReleaseCommitment({
            grantId: grantId,
            gateway: msg.sender,
            grantee: grantee,
            purpose: purpose,
            receiptCommitment: receiptCommitment,
            recordedAt: recordedAt
        });

        emit ReleaseRecorded(releaseId, grantId, grantee, purpose, receiptCommitment, msg.sender, recordedAt);
    }

    /// @inheritdoc IConsentManager
    function releaseExists(bytes32 releaseId) external view returns (bool) {
        return _releases[releaseId].gateway != address(0);
    }

    /// @inheritdoc IConsentManager
    function getRelease(bytes32 releaseId) external view returns (ReleaseCommitment memory) {
        ReleaseCommitment memory commitment = _releases[releaseId];
        if (commitment.gateway == address(0)) {
            revert ReleaseNotFound(releaseId);
        }
        return commitment;
    }

    /// @inheritdoc IConsentManager
    function verifyReceiptCommitment(bytes32 releaseId, bytes32 receiptCommitment) external view returns (bool) {
        ReleaseCommitment storage commitment = _releases[releaseId];
        return commitment.gateway != address(0) && receiptCommitment != bytes32(0)
            && commitment.receiptCommitment == receiptCommitment;
    }
}
