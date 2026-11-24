// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IConsentManager
/// @notice Interface for patient-controlled sharing grants and gateway release-receipt commitments.
interface IConsentManager {
    /// @notice Declared sharing purpose enforced per grant.
    enum Purpose {
        None,
        Treatment,
        Research
    }

    /// @notice Lifecycle status of an on-chain consent grant.
    enum GrantStatus {
        NotFound,
        Active,
        Expired,
        Revoked
    }

    /// @notice Immutable-scope patient consent grant with explicit recipient, purpose, and expiry.
    struct ConsentGrant {
        address owner;
        address grantee;
        Purpose purpose;
        bytes32 scopeCommitment;
        uint64 grantedAt;
        uint64 expiresAt;
        bool revoked;
        uint64 revokedAt;
    }

    /// @notice On-chain commitment to an encrypted off-chain gateway release receipt.
    struct ReleaseCommitment {
        bytes32 grantId;
        address gateway;
        address grantee;
        Purpose purpose;
        bytes32 receiptCommitment;
        uint64 recordedAt;
    }

    error UnauthorizedAdmin(address caller);
    error InvalidGatewayAddress();
    error UnauthorizedGateway(address caller);
    error InvalidGrantId();
    error GrantAlreadyExists(bytes32 grantId);
    error InvalidGrantee();
    error InvalidPurpose();
    error InvalidScopeCommitment();
    error ExpiryNotInFuture(uint64 expiresAt, uint64 currentTime);
    error GrantNotFound(bytes32 grantId);
    error NotGrantOwner(bytes32 grantId, address caller);
    error GrantAlreadyRevoked(bytes32 grantId);
    error GrantAlreadyExpired(bytes32 grantId);
    error InvalidReleaseId();
    error InvalidReceiptCommitment();
    error ReleaseAlreadyRecorded(bytes32 releaseId);
    error ReleaseNotFound(bytes32 releaseId);
    error GrantIsRevoked(bytes32 grantId);
    error GrantIsExpired(bytes32 grantId);
    error GranteeMismatch(bytes32 grantId, address expected, address actual);
    error PurposeMismatch(bytes32 grantId, Purpose expected, Purpose actual);
    error ScopeMismatch(bytes32 grantId);

    /// @notice Emitted when the admin updates gateway allowlist authorization.
    event GatewayAuthorizationUpdated(address indexed gateway, bool authorized);

    /// @notice Emitted when a patient creates a new consent grant.
    event GrantCreated(
        bytes32 indexed grantId,
        address indexed owner,
        address indexed grantee,
        Purpose purpose,
        bytes32 scopeCommitment,
        uint64 expiresAt,
        uint64 grantedAt
    );

    /// @notice Emitted when a patient revokes an active consent grant.
    event GrantRevoked(bytes32 indexed grantId, address indexed owner, uint64 revokedAt);

    /// @notice Emitted when an authorized gateway anchors a release-receipt commitment.
    event ReleaseRecorded(
        bytes32 indexed releaseId,
        bytes32 indexed grantId,
        address indexed grantee,
        Purpose purpose,
        bytes32 receiptCommitment,
        address gateway,
        uint64 recordedAt
    );

    /// @notice Returns the contract administrator allowed to manage gateway authorization.
    function admin() external view returns (address);

    /// @notice Returns true if the given address is allowlisted to anchor release receipts.
    function authorizedGateways(address gateway) external view returns (bool);

    /// @notice Adds or removes a gateway signer from the allowlist.
    /// @param gateway Address of the gateway signer.
    /// @param authorized Whether the gateway is authorized.
    function setGatewayAuthorization(address gateway, bool authorized) external;

    /// @notice Creates a patient-signed consent grant binding recipient, purpose, version-list commitment, and expiry.
    /// @param grantId Unique opaque grant identifier (must be non-zero and unused).
    /// @param grantee Named clinician or researcher wallet authorized to receive data.
    /// @param purpose Declared sharing purpose (Treatment or Research).
    /// @param scopeCommitment Deterministic keccak256 commitment over patient and sorted version identifiers.
    /// @param expiresAt Unix timestamp (seconds); authorization requires block.timestamp < expiresAt.
    function grantAccess(bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment, uint64 expiresAt)
        external;

    /// @notice Revokes an existing non-expired grant owned by the caller to block future releases.
    /// @param grantId Identifier of the grant to revoke.
    function revokeGrant(bytes32 grantId) external;

    /// @notice Returns the stored ConsentGrant struct or reverts if not found.
    function getGrant(bytes32 grantId) external view returns (ConsentGrant memory);

    /// @notice Returns the computed lifecycle status of a grant at the current block timestamp.
    function getGrantStatus(bytes32 grantId) external view returns (GrantStatus);

    /// @notice Evaluates whether a grant currently authorizes access for the exact recipient, purpose, and scope.
    function isAccessAuthorized(bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment)
        external
        view
        returns (bool);

    /// @notice Atomically verifies grant validity and anchors a gateway release-receipt commitment.
    /// @param releaseId Unique opaque release attempt identifier.
    /// @param grantId Grant identifier authorizing the release.
    /// @param grantee Recipient address being served.
    /// @param purpose Purpose being served.
    /// @param scopeCommitment Expected immutable scope commitment.
    /// @param receiptCommitment SHA-256 digest of the encrypted off-chain ReleaseReceipt envelope.
    function recordRelease(
        bytes32 releaseId,
        bytes32 grantId,
        address grantee,
        Purpose purpose,
        bytes32 scopeCommitment,
        bytes32 receiptCommitment
    ) external;

    /// @notice Returns true if a release commitment has been recorded for releaseId.
    function releaseExists(bytes32 releaseId) external view returns (bool);

    /// @notice Returns the stored ReleaseCommitment struct or reverts if not found.
    function getRelease(bytes32 releaseId) external view returns (ReleaseCommitment memory);

    /// @notice Verifies whether a candidate receipt commitment matches the anchored release commitment.
    function verifyReceiptCommitment(bytes32 releaseId, bytes32 receiptCommitment) external view returns (bool);
}
