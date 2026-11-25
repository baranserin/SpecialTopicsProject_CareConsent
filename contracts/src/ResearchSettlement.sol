// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IConsentManager} from "./interfaces/IConsentManager.sol";
import {IResearchSettlement} from "./interfaces/IResearchSettlement.sol";

/// @title ResearchSettlement
/// @notice Escrows valueless development test credits for research requests and settles approved exports once per releaseId.
/// @dev Requires a separate Purpose.Research grant and an allowlisted gateway release commitment on ConsentManager.
contract ResearchSettlement is IResearchSettlement {
    enum StoredState {
        None,
        Funded,
        Refused,
        Settled,
        Refunded
    }

    struct StoredRequest {
        address researcher;
        address patient;
        bytes32 scopeCommitment;
        uint256 fee;
        uint64 fundedAt;
        uint64 expiresAt;
        StoredState state;
        bytes32 settledReleaseId;
        uint64 settledAt;
    }

    address public immutable admin;
    IConsentManager public immutable consentManager;
    mapping(address => uint256) public creditBalances;

    mapping(bytes32 => StoredRequest) private _requests;
    mapping(bytes32 => SettlementRecord) private _settlements;

    /// @notice Deploys ResearchSettlement bound to a deployed ConsentManager instance.
    /// @param consentManager_ Address of the ConsentManager contract.
    constructor(address consentManager_) {
        if (consentManager_ == address(0)) {
            revert InvalidConsentManager();
        }
        admin = msg.sender;
        consentManager = IConsentManager(consentManager_);
    }

    /// @inheritdoc IResearchSettlement
    function mintTestCredits(address account, uint256 amount) external {
        if (msg.sender != admin) {
            revert UnauthorizedAdmin(msg.sender);
        }
        if (account == address(0)) {
            revert InvalidAccount();
        }
        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 newBalance = creditBalances[account] + amount;
        creditBalances[account] = newBalance;
        emit TestCreditsMinted(account, amount, newBalance);
    }

    /// @inheritdoc IResearchSettlement
    function fundResearchRequest(
        bytes32 requestId,
        address patient,
        bytes32 scopeCommitment,
        uint256 fee,
        uint64 expiresAt
    ) external {
        if (requestId == bytes32(0)) {
            revert InvalidRequestId();
        }
        if (_requests[requestId].state != StoredState.None) {
            revert RequestAlreadyExists(requestId);
        }
        if (patient == address(0) || patient == msg.sender) {
            revert InvalidPatient();
        }
        if (scopeCommitment == bytes32(0)) {
            revert InvalidScopeCommitment();
        }
        if (fee == 0) {
            revert InvalidFee();
        }

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 currentTime = uint64(block.timestamp);
        if (expiresAt <= currentTime) {
            revert ExpiryNotInFuture(expiresAt, currentTime);
        }

        uint256 available = creditBalances[msg.sender];
        if (available < fee) {
            revert InsufficientTestCredits(msg.sender, fee, available);
        }

        creditBalances[msg.sender] = available - fee;
        _requests[requestId] = StoredRequest({
            researcher: msg.sender,
            patient: patient,
            scopeCommitment: scopeCommitment,
            fee: fee,
            fundedAt: currentTime,
            expiresAt: expiresAt,
            state: StoredState.Funded,
            settledReleaseId: bytes32(0),
            settledAt: 0
        });

        emit ResearchRequestFunded(requestId, msg.sender, patient, scopeCommitment, fee, expiresAt, currentTime);
    }

    /// @inheritdoc IResearchSettlement
    function refuseResearchRequest(bytes32 requestId) external {
        StoredRequest storage req = _requests[requestId];
        _requireFundedState(requestId, req.state);
        if (msg.sender != req.patient) {
            revert NotRequestPatient(requestId, msg.sender);
        }
        // Strict expiry boundary matches ConsentManager (block.timestamp < expiresAt).
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= req.expiresAt) {
            revert RequestIsExpired(requestId);
        }

        req.state = StoredState.Refused;
        creditBalances[req.researcher] += req.fee;

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        emit ResearchRequestRefused(requestId, msg.sender, req.researcher, req.fee, uint64(block.timestamp));
    }

    /// @inheritdoc IResearchSettlement
    function refundExpiredRequest(bytes32 requestId) external {
        StoredRequest storage req = _requests[requestId];
        _requireFundedState(requestId, req.state);

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 currentTime = uint64(block.timestamp);
        if (currentTime < req.expiresAt) {
            revert RequestNotExpired(requestId, req.expiresAt, currentTime);
        }

        req.state = StoredState.Refunded;
        creditBalances[req.researcher] += req.fee;

        emit ResearchRequestRefunded(requestId, req.researcher, req.fee, currentTime);
    }

    /// @inheritdoc IResearchSettlement
    function settleResearch(bytes32 requestId, bytes32 releaseId) external {
        if (!consentManager.authorizedGateways(msg.sender)) {
            revert UnauthorizedGateway(msg.sender);
        }
        if (requestId == bytes32(0)) {
            revert InvalidRequestId();
        }
        if (releaseId == bytes32(0)) {
            revert InvalidReleaseId();
        }
        if (_settlements[releaseId].settled) {
            revert ReleaseAlreadySettled(releaseId);
        }

        StoredRequest storage req = _requests[requestId];
        _requireFundedState(requestId, req.state);
        // Strict expiry boundary requires block.timestamp < expiresAt.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= req.expiresAt) {
            revert RequestIsExpired(requestId);
        }
        if (!consentManager.releaseExists(releaseId)) {
            revert ReleaseNotAttested(releaseId);
        }

        IConsentManager.ReleaseCommitment memory rel = consentManager.getRelease(releaseId);
        IConsentManager.ConsentGrant memory grant = consentManager.getGrant(rel.grantId);

        if (rel.purpose != IConsentManager.Purpose.Research) {
            revert NotResearchPurpose(rel.grantId, rel.purpose);
        }
        if (grant.purpose != IConsentManager.Purpose.Research) {
            revert NotResearchPurpose(rel.grantId, grant.purpose);
        }
        if (grant.revoked) {
            revert GrantIsRevoked(rel.grantId);
        }
        // Strict expiry boundary requires block.timestamp < grant.expiresAt.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= grant.expiresAt) {
            revert GrantIsExpired(rel.grantId);
        }
        if (grant.owner != req.patient) {
            revert PatientMismatch(requestId, req.patient, grant.owner);
        }
        if (rel.grantee != req.researcher || grant.grantee != req.researcher) {
            address actualResearcher = rel.grantee != req.researcher ? rel.grantee : grant.grantee;
            revert ResearcherMismatch(requestId, req.researcher, actualResearcher);
        }
        if (grant.scopeCommitment != req.scopeCommitment) {
            revert ScopeMismatch(requestId);
        }

        // Unix epoch seconds fit well within uint64 for over 584 billion years.
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 settledAt = uint64(block.timestamp);
        req.state = StoredState.Settled;
        req.settledReleaseId = releaseId;
        req.settledAt = settledAt;

        _settlements[releaseId] = SettlementRecord({
            requestId: requestId,
            grantId: rel.grantId,
            patient: req.patient,
            researcher: req.researcher,
            fee: req.fee,
            gateway: msg.sender,
            settledAt: settledAt,
            settled: true
        });

        creditBalances[req.patient] += req.fee;

        emit ResearchSettled(
            releaseId, requestId, rel.grantId, req.patient, req.researcher, req.fee, msg.sender, settledAt
        );
    }

    /// @inheritdoc IResearchSettlement
    function getRequest(bytes32 requestId) external view returns (ResearchRequest memory) {
        StoredRequest storage req = _requests[requestId];
        if (req.state == StoredState.None) {
            revert RequestNotFound(requestId);
        }
        return ResearchRequest({
            researcher: req.researcher,
            patient: req.patient,
            scopeCommitment: req.scopeCommitment,
            fee: req.fee,
            fundedAt: req.fundedAt,
            expiresAt: req.expiresAt,
            status: _effectiveStatus(req),
            settledReleaseId: req.settledReleaseId,
            settledAt: req.settledAt
        });
    }

    /// @inheritdoc IResearchSettlement
    function getRequestStatus(bytes32 requestId) external view returns (RequestStatus) {
        return _effectiveStatus(_requests[requestId]);
    }

    /// @inheritdoc IResearchSettlement
    function isReleaseSettled(bytes32 releaseId) external view returns (bool) {
        return _settlements[releaseId].settled;
    }

    /// @inheritdoc IResearchSettlement
    function getSettlement(bytes32 releaseId) external view returns (SettlementRecord memory) {
        SettlementRecord memory record = _settlements[releaseId];
        if (!record.settled) {
            revert SettlementNotFound(releaseId);
        }
        return record;
    }

    function _requireFundedState(bytes32 requestId, StoredState state) internal pure {
        if (state == StoredState.None) {
            revert RequestNotFound(requestId);
        }
        if (state == StoredState.Refused) {
            revert RequestAlreadyRefused(requestId);
        }
        if (state == StoredState.Settled) {
            revert RequestAlreadySettled(requestId);
        }
        if (state == StoredState.Refunded) {
            revert RequestAlreadyRefunded(requestId);
        }
    }

    function _effectiveStatus(StoredRequest storage req) internal view returns (RequestStatus) {
        if (req.state == StoredState.None) {
            return RequestStatus.NotFound;
        }
        if (req.state == StoredState.Refused) {
            return RequestStatus.Refused;
        }
        if (req.state == StoredState.Settled) {
            return RequestStatus.Settled;
        }
        if (req.state == StoredState.Refunded) {
            return RequestStatus.Refunded;
        }
        // Strict expiry boundary matches ConsentManager (block.timestamp < expiresAt).
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp >= req.expiresAt) {
            return RequestStatus.Expired;
        }
        return RequestStatus.Funded;
    }
}
