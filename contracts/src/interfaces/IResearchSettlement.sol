// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IConsentManager} from "./IConsentManager.sol";

/// @title IResearchSettlement
/// @notice Interface for funded research-sharing requests, valueless test-credit escrow, and idempotent settlement.
interface IResearchSettlement {
    /// @notice Effective lifecycle status of a research funding request.
    enum RequestStatus {
        NotFound,
        Funded,
        Refused,
        Settled,
        Refunded,
        Expired
    }

    /// @notice View representation of a funded research-sharing request.
    struct ResearchRequest {
        address researcher;
        address patient;
        bytes32 scopeCommitment;
        uint256 fee;
        uint64 fundedAt;
        uint64 expiresAt;
        RequestStatus status;
        bytes32 settledReleaseId;
        uint64 settledAt;
    }

    /// @notice Immutable record of a completed one-time research settlement.
    struct SettlementRecord {
        bytes32 requestId;
        bytes32 grantId;
        address patient;
        address researcher;
        uint256 fee;
        address gateway;
        uint64 settledAt;
        bool settled;
    }

    error InvalidConsentManager();
    error UnauthorizedAdmin(address caller);
    error UnauthorizedGateway(address caller);
    error InvalidAccount();
    error InvalidAmount();
    error InvalidRequestId();
    error RequestAlreadyExists(bytes32 requestId);
    error InvalidPatient();
    error InvalidScopeCommitment();
    error InvalidFee();
    error ExpiryNotInFuture(uint64 expiresAt, uint64 currentTime);
    error InsufficientTestCredits(address researcher, uint256 required, uint256 available);
    error RequestNotFound(bytes32 requestId);
    error NotRequestPatient(bytes32 requestId, address caller);
    error RequestAlreadyRefused(bytes32 requestId);
    error RequestAlreadySettled(bytes32 requestId);
    error RequestAlreadyRefunded(bytes32 requestId);
    error RequestIsExpired(bytes32 requestId);
    error RequestNotExpired(bytes32 requestId, uint64 expiresAt, uint64 currentTime);
    error InvalidReleaseId();
    error ReleaseAlreadySettled(bytes32 releaseId);
    error ReleaseNotAttested(bytes32 releaseId);
    error NotResearchPurpose(bytes32 grantId, IConsentManager.Purpose actual);
    error GrantIsRevoked(bytes32 grantId);
    error GrantIsExpired(bytes32 grantId);
    error PatientMismatch(bytes32 requestId, address expected, address actual);
    error ResearcherMismatch(bytes32 requestId, address expected, address actual);
    error ScopeMismatch(bytes32 requestId);
    error SettlementNotFound(bytes32 releaseId);

    /// @notice Emitted when the administrator mints valueless local test credits to an account.
    event TestCreditsMinted(address indexed account, uint256 amount, uint256 newBalance);

    /// @notice Emitted when a researcher funds a new research-sharing request in escrow.
    event ResearchRequestFunded(
        bytes32 indexed requestId,
        address indexed researcher,
        address indexed patient,
        bytes32 scopeCommitment,
        uint256 fee,
        uint64 expiresAt,
        uint64 fundedAt
    );

    /// @notice Emitted when the named patient refuses a funded request and the fee returns to the researcher.
    event ResearchRequestRefused(
        bytes32 indexed requestId,
        address indexed patient,
        address indexed researcher,
        uint256 refundedFee,
        uint64 refusedAt
    );

    /// @notice Emitted when an expired unused request is refunded back to the researcher.
    event ResearchRequestRefunded(
        bytes32 indexed requestId, address indexed researcher, uint256 refundedFee, uint64 refundedAt
    );

    /// @notice Emitted when an authorized gateway attestation settles a research export exactly once.
    event ResearchSettled(
        bytes32 indexed releaseId,
        bytes32 indexed requestId,
        bytes32 indexed grantId,
        address patient,
        address researcher,
        uint256 fee,
        address gateway,
        uint64 settledAt
    );

    /// @notice Returns the administrator allowed to mint valueless development test credits.
    function admin() external view returns (address);

    /// @notice Returns the ConsentManager contract verified during settlement.
    function consentManager() external view returns (IConsentManager);

    /// @notice Returns the current valueless test-credit balance of an account.
    function creditBalances(address account) external view returns (uint256);

    /// @notice Mints valueless development test credits to a target account (admin only).
    function mintTestCredits(address account, uint256 amount) external;

    /// @notice Escrows a test-credit fee for a patient-specific research export request.
    function fundResearchRequest(
        bytes32 requestId,
        address patient,
        bytes32 scopeCommitment,
        uint256 fee,
        uint64 expiresAt
    ) external;

    /// @notice Allows the named patient to refuse an active funded request, immediately refunding the researcher.
    function refuseResearchRequest(bytes32 requestId) external;

    /// @notice Refunds an unused funded request after its expiry timestamp has been reached.
    function refundExpiredRequest(bytes32 requestId) external;

    /// @notice Credits the patient once for a gateway-attested research release matching a funded request.
    function settleResearch(bytes32 requestId, bytes32 releaseId) external;

    /// @notice Returns the full research request details including effective expiry status.
    function getRequest(bytes32 requestId) external view returns (ResearchRequest memory);

    /// @notice Returns the effective status of a research request at the current block timestamp.
    function getRequestStatus(bytes32 requestId) external view returns (RequestStatus);

    /// @notice Returns true if the given release identifier has already been settled.
    function isReleaseSettled(bytes32 releaseId) external view returns (bool);

    /// @notice Returns the settlement record for a release identifier or reverts if unsettled.
    function getSettlement(bytes32 releaseId) external view returns (SettlementRecord memory);
}
