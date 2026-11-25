// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ConsentManager} from "../src/ConsentManager.sol";
import {IConsentManager} from "../src/interfaces/IConsentManager.sol";
import {ResearchSettlement} from "../src/ResearchSettlement.sol";
import {IResearchSettlement} from "../src/interfaces/IResearchSettlement.sol";

contract ResearchSettlementTest is Test {
    ConsentManager internal consent;
    ResearchSettlement internal settlement;

    address internal constant ADMIN = address(0xAD01);
    address internal constant GATEWAY = address(0x6A7E);
    address internal constant PATIENT = address(0xA11CE);
    address internal constant PATIENT_2 = address(0xA11CF);
    address internal constant RESEARCHER = address(0xAE5E);
    address internal constant RESEARCHER_2 = address(0xAE5F);
    address internal constant CLINICIAN = address(0xC11A);
    address internal constant ATTACKER = address(0xBAD);

    bytes32 internal constant VERSION_1 = keccak256("CareConsent:Version:v1:med-001");
    bytes32 internal constant VERSION_2 = keccak256("CareConsent:Version:v1:obs-002");
    bytes32 internal constant REQUEST_1 = keccak256("CareConsent:ResearchRequest:v1:req-001");
    bytes32 internal constant REQUEST_2 = keccak256("CareConsent:ResearchRequest:v1:req-002");
    bytes32 internal constant GRANT_RESEARCH = keccak256("CareConsent:Grant:v1:res-grant-001");
    bytes32 internal constant GRANT_TREATMENT = keccak256("CareConsent:Grant:v1:trt-grant-001");
    bytes32 internal constant GRANT_OTHER = keccak256("CareConsent:Grant:v1:other-grant-001");
    bytes32 internal constant RELEASE_1 = keccak256("CareConsent:Release:v1:rel-001");
    bytes32 internal constant RELEASE_2 = keccak256("CareConsent:Release:v1:rel-002");

    uint64 internal constant INITIAL_TIME = 1_795_000_000;
    uint64 internal constant SEVEN_DAYS = 7 days;
    uint256 internal constant INITIAL_CREDITS = 500;
    uint256 internal constant RESEARCH_FEE = 150;

    bytes32 internal receipt1;
    bytes32 internal receipt2;
    bytes32 internal scopeV1;
    bytes32 internal scopeV2;

    function setUp() public {
        vm.warp(INITIAL_TIME);

        vm.startPrank(ADMIN);
        consent = new ConsentManager(GATEWAY);
        settlement = new ResearchSettlement(address(consent));
        settlement.mintTestCredits(RESEARCHER, INITIAL_CREDITS);
        vm.stopPrank();

        receipt1 = sha256("encrypted-research-receipt-1");
        receipt2 = sha256("encrypted-research-receipt-2");
        scopeV1 = _computeScopeCommitment(PATIENT, VERSION_1);
        scopeV2 = _computeScopeCommitment(PATIENT, VERSION_2);
    }

    function _computeScopeCommitment(address patient, bytes32 versionId) internal pure returns (bytes32) {
        bytes32[] memory versions = new bytes32[](1);
        versions[0] = versionId;
        return keccak256(abi.encode(patient, versions));
    }

    function _fundDefaultRequest() internal returns (uint64 reqExpiresAt) {
        reqExpiresAt = INITIAL_TIME + SEVEN_DAYS;
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, RESEARCH_FEE, reqExpiresAt);
    }

    function _createResearchGrantAndRelease(bytes32 grantId, bytes32 releaseId, uint64 grantExpiresAt) internal {
        vm.prank(PATIENT);
        consent.grantAccess(grantId, RESEARCHER, IConsentManager.Purpose.Research, scopeV1, grantExpiresAt);

        vm.prank(GATEWAY);
        consent.recordRelease(releaseId, grantId, RESEARCHER, IConsentManager.Purpose.Research, scopeV1, receipt1);
    }

    // -------------------------------------------------------------------------
    // Constructor & Test-Credit Minting Tests
    // -------------------------------------------------------------------------

    function test_Constructor_SetsAdminAndConsentManager() public view {
        assertEq(settlement.admin(), ADMIN);
        assertEq(address(settlement.consentManager()), address(consent));
        assertEq(settlement.creditBalances(RESEARCHER), INITIAL_CREDITS);
    }

    function test_Constructor_RevertsOnZeroConsentManager() public {
        vm.expectRevert(IResearchSettlement.InvalidConsentManager.selector);
        new ResearchSettlement(address(0));
    }

    function test_MintTestCredits_AdminMintsAndEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit IResearchSettlement.TestCreditsMinted(RESEARCHER_2, 250, 250);

        vm.prank(ADMIN);
        settlement.mintTestCredits(RESEARCHER_2, 250);

        assertEq(settlement.creditBalances(RESEARCHER_2), 250);
    }

    function test_MintTestCredits_RevertsForNonAdminZeroAddressOrZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.UnauthorizedAdmin.selector, ATTACKER));
        vm.prank(ATTACKER);
        settlement.mintTestCredits(RESEARCHER_2, 100);

        vm.expectRevert(IResearchSettlement.InvalidAccount.selector);
        vm.prank(ADMIN);
        settlement.mintTestCredits(address(0), 100);

        vm.expectRevert(IResearchSettlement.InvalidAmount.selector);
        vm.prank(ADMIN);
        settlement.mintTestCredits(RESEARCHER_2, 0);
    }

    // -------------------------------------------------------------------------
    // Funding Request Tests
    // -------------------------------------------------------------------------

    function test_FundResearchRequest_EscrowsFeeAndEmitsEvent() public {
        uint64 expiresAt = INITIAL_TIME + SEVEN_DAYS;

        vm.expectEmit(true, true, true, true);
        emit IResearchSettlement.ResearchRequestFunded(
            REQUEST_1, RESEARCHER, PATIENT, scopeV1, RESEARCH_FEE, expiresAt, INITIAL_TIME
        );

        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, RESEARCH_FEE, expiresAt);

        assertEq(settlement.creditBalances(RESEARCHER), INITIAL_CREDITS - RESEARCH_FEE);
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.Funded));

        IResearchSettlement.ResearchRequest memory req = settlement.getRequest(REQUEST_1);
        assertEq(req.researcher, RESEARCHER);
        assertEq(req.patient, PATIENT);
        assertEq(req.scopeCommitment, scopeV1);
        assertEq(req.fee, RESEARCH_FEE);
        assertEq(req.fundedAt, INITIAL_TIME);
        assertEq(req.expiresAt, expiresAt);
        assertEq(uint8(req.status), uint8(IResearchSettlement.RequestStatus.Funded));
        assertEq(req.settledReleaseId, bytes32(0));
        assertEq(req.settledAt, 0);
    }

    function test_FundResearchRequest_RevertsOnInsufficientCredits() public {
        uint256 tooMuch = INITIAL_CREDITS + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                IResearchSettlement.InsufficientTestCredits.selector, RESEARCHER, tooMuch, INITIAL_CREDITS
            )
        );
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, tooMuch, INITIAL_TIME + SEVEN_DAYS);

        assertEq(settlement.creditBalances(RESEARCHER), INITIAL_CREDITS);
    }

    function test_FundResearchRequest_RevertsOnInvalidInputsAndDuplicateId() public {
        uint64 expiresAt = INITIAL_TIME + SEVEN_DAYS;

        vm.expectRevert(IResearchSettlement.InvalidRequestId.selector);
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(bytes32(0), PATIENT, scopeV1, RESEARCH_FEE, expiresAt);

        vm.expectRevert(IResearchSettlement.InvalidPatient.selector);
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, address(0), scopeV1, RESEARCH_FEE, expiresAt);

        vm.expectRevert(IResearchSettlement.InvalidPatient.selector);
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, RESEARCHER, scopeV1, RESEARCH_FEE, expiresAt);

        vm.expectRevert(IResearchSettlement.InvalidScopeCommitment.selector);
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, bytes32(0), RESEARCH_FEE, expiresAt);

        vm.expectRevert(IResearchSettlement.InvalidFee.selector);
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, 0, expiresAt);

        vm.expectRevert(
            abi.encodeWithSelector(IResearchSettlement.ExpiryNotInFuture.selector, INITIAL_TIME, INITIAL_TIME)
        );
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, RESEARCH_FEE, INITIAL_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(IResearchSettlement.ExpiryNotInFuture.selector, INITIAL_TIME - 1, INITIAL_TIME)
        );
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, RESEARCH_FEE, INITIAL_TIME - 1);

        _fundDefaultRequest();
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadyExists.selector, REQUEST_1));
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_1, PATIENT, scopeV1, RESEARCH_FEE, expiresAt);
    }

    // -------------------------------------------------------------------------
    // Refusal & Expired Refund Tests
    // -------------------------------------------------------------------------

    function test_RefuseResearchRequest_PatientRefusesAndRefundsResearcher() public {
        _fundDefaultRequest();

        uint64 refuseTime = INITIAL_TIME + 300;
        vm.warp(refuseTime);

        vm.expectEmit(true, true, true, true);
        emit IResearchSettlement.ResearchRequestRefused(REQUEST_1, PATIENT, RESEARCHER, RESEARCH_FEE, refuseTime);

        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_1);

        assertEq(settlement.creditBalances(RESEARCHER), INITIAL_CREDITS);
        assertEq(settlement.creditBalances(PATIENT), 0);
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.Refused));
    }

    function test_RefuseResearchRequest_RevertsForNonPatientMissingExpiredOrTerminalStates() public {
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestNotFound.selector, REQUEST_1));
        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_1);

        uint64 expiresAt = _fundDefaultRequest();

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.NotRequestPatient.selector, REQUEST_1, ATTACKER));
        vm.prank(ATTACKER);
        settlement.refuseResearchRequest(REQUEST_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.NotRequestPatient.selector, REQUEST_1, RESEARCHER));
        vm.prank(RESEARCHER);
        settlement.refuseResearchRequest(REQUEST_1);

        vm.warp(expiresAt);
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestIsExpired.selector, REQUEST_1));
        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_1);

        // New request refused once cannot be refused again.
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_2, PATIENT, scopeV1, RESEARCH_FEE, expiresAt + SEVEN_DAYS);
        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_2);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadyRefused.selector, REQUEST_2));
        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_2);
    }

    function test_RefundExpiredRequest_RevertsBeforeExpiryAndSucceedsAtExactExpiry() public {
        uint64 expiresAt = _fundDefaultRequest();

        // T - 1 second: still Funded, cannot refund yet.
        vm.warp(expiresAt - 1);
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.Funded));

        vm.expectRevert(
            abi.encodeWithSelector(IResearchSettlement.RequestNotExpired.selector, REQUEST_1, expiresAt, expiresAt - 1)
        );
        settlement.refundExpiredRequest(REQUEST_1);

        // Exactly T: status flips to Expired and refund restores researcher credits.
        vm.warp(expiresAt);
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.Expired));

        vm.expectEmit(true, true, false, true);
        emit IResearchSettlement.ResearchRequestRefunded(REQUEST_1, RESEARCHER, RESEARCH_FEE, expiresAt);

        settlement.refundExpiredRequest(REQUEST_1);

        assertEq(settlement.creditBalances(RESEARCHER), INITIAL_CREDITS);
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.Refunded));
    }

    function test_RefundExpiredRequest_RevertsOnTerminalOrMissingStates() public {
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestNotFound.selector, REQUEST_1));
        settlement.refundExpiredRequest(REQUEST_1);

        uint64 expiresAt = _fundDefaultRequest();
        vm.warp(expiresAt);
        settlement.refundExpiredRequest(REQUEST_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadyRefunded.selector, REQUEST_1));
        settlement.refundExpiredRequest(REQUEST_1);

        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_2, PATIENT, scopeV1, RESEARCH_FEE, expiresAt + SEVEN_DAYS);
        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_2);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadyRefused.selector, REQUEST_2));
        settlement.refundExpiredRequest(REQUEST_2);
    }

    // -------------------------------------------------------------------------
    // Settlement Matrix Tests (TC10)
    // -------------------------------------------------------------------------

    function test_SettleResearch_NominalApprovedExportCreditsPatientOnce() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        uint64 settleTime = INITIAL_TIME + 600;
        vm.warp(settleTime);

        vm.expectEmit(true, true, true, true);
        emit IResearchSettlement.ResearchSettled(
            RELEASE_1, REQUEST_1, GRANT_RESEARCH, PATIENT, RESEARCHER, RESEARCH_FEE, GATEWAY, settleTime
        );

        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), RESEARCH_FEE);
        assertEq(settlement.creditBalances(RESEARCHER), INITIAL_CREDITS - RESEARCH_FEE);
        assertTrue(settlement.isReleaseSettled(RELEASE_1));
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.Settled));

        IResearchSettlement.ResearchRequest memory req = settlement.getRequest(REQUEST_1);
        assertEq(req.settledReleaseId, RELEASE_1);
        assertEq(req.settledAt, settleTime);

        IResearchSettlement.SettlementRecord memory rec = settlement.getSettlement(RELEASE_1);
        assertEq(rec.requestId, REQUEST_1);
        assertEq(rec.grantId, GRANT_RESEARCH);
        assertEq(rec.patient, PATIENT);
        assertEq(rec.researcher, RESEARCHER);
        assertEq(rec.fee, RESEARCH_FEE);
        assertEq(rec.gateway, GATEWAY);
        assertEq(rec.settledAt, settleTime);
        assertTrue(rec.settled);
    }

    function test_SettleResearch_RevertsOnDuplicateReleaseIdRetry() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        // Retrying the same request & releaseId must fail without paying twice.
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.ReleaseAlreadySettled.selector, RELEASE_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        // Trying to reuse the same releaseId against a second funded request must also fail.
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_2, PATIENT, scopeV1, RESEARCH_FEE, reqExpiresAt);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.ReleaseAlreadySettled.selector, RELEASE_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_2, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), RESEARCH_FEE);
    }

    function test_SettleResearch_RevertsWhenRequestAlreadySettledWithDifferentReleaseId() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        vm.prank(GATEWAY);
        consent.recordRelease(
            RELEASE_2, GRANT_RESEARCH, RESEARCHER, IConsentManager.Purpose.Research, scopeV1, receipt2
        );

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadySettled.selector, REQUEST_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_2);

        assertFalse(settlement.isReleaseSettled(RELEASE_2));
        assertEq(settlement.creditBalances(PATIENT), RESEARCH_FEE);

        // Settled request also cannot be refunded or refused afterwards.
        vm.warp(reqExpiresAt);
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadySettled.selector, REQUEST_1));
        settlement.refundExpiredRequest(REQUEST_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadySettled.selector, REQUEST_1));
        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_1);
    }

    function test_SettleResearch_RevertsForUntrustedAttesterOrDeauthorizedGateway() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.UnauthorizedGateway.selector, PATIENT));
        vm.prank(PATIENT);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.UnauthorizedGateway.selector, RESEARCHER));
        vm.prank(RESEARCHER);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.UnauthorizedGateway.selector, ATTACKER));
        vm.prank(ATTACKER);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        vm.prank(ADMIN);
        consent.setGatewayAuthorization(GATEWAY, false);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.UnauthorizedGateway.selector, GATEWAY));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), 0);
        assertFalse(settlement.isReleaseSettled(RELEASE_1));
    }

    function test_SettleResearch_RevertsWhenReleaseNotAttestedOnConsentManager() public {
        _fundDefaultRequest();

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.ReleaseNotAttested.selector, RELEASE_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), 0);
    }

    function test_SettleResearch_RevertsOnTreatmentGrantRelease() public {
        uint64 reqExpiresAt = _fundDefaultRequest();

        vm.prank(PATIENT);
        consent.grantAccess(
            GRANT_TREATMENT, CLINICIAN, IConsentManager.Purpose.Treatment, scopeV1, reqExpiresAt + 1 days
        );
        vm.prank(GATEWAY);
        consent.recordRelease(
            RELEASE_1, GRANT_TREATMENT, CLINICIAN, IConsentManager.Purpose.Treatment, scopeV1, receipt1
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IResearchSettlement.NotResearchPurpose.selector, GRANT_TREATMENT, IConsentManager.Purpose.Treatment
            )
        );
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), 0);
        assertFalse(settlement.isReleaseSettled(RELEASE_1));
    }

    function test_SettleResearch_RevertsWhenRequestMissingRefusedOrRefunded() public {
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestNotFound.selector, REQUEST_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        vm.prank(PATIENT);
        settlement.refuseResearchRequest(REQUEST_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadyRefused.selector, REQUEST_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_2, PATIENT, scopeV1, RESEARCH_FEE, reqExpiresAt);
        vm.warp(reqExpiresAt);
        settlement.refundExpiredRequest(REQUEST_2);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestAlreadyRefunded.selector, REQUEST_2));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_2, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), 0);
    }

    function test_SettleResearch_EnforcesRequestExpiryBoundary() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        // Exactly T: request expired -> reverts without transfer.
        vm.warp(reqExpiresAt);
        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestIsExpired.selector, REQUEST_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);
        assertEq(settlement.creditBalances(PATIENT), 0);

        // T - 1 on a fresh request succeeds.
        uint64 req2Expires = reqExpiresAt + 1 days;
        vm.prank(RESEARCHER);
        settlement.fundResearchRequest(REQUEST_2, PATIENT, scopeV1, RESEARCH_FEE, req2Expires);

        vm.prank(GATEWAY);
        consent.recordRelease(
            RELEASE_2, GRANT_RESEARCH, RESEARCHER, IConsentManager.Purpose.Research, scopeV1, receipt2
        );

        vm.warp(req2Expires - 1);
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_2, RELEASE_2);
        assertEq(settlement.creditBalances(PATIENT), RESEARCH_FEE);
    }

    function test_SettleResearch_RevertsWhenGrantExpiredAfterReleaseRecorded() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        uint64 grantExpiresAt = INITIAL_TIME + 1 days;
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, grantExpiresAt);

        // Request is still valid (7 days), but grant expired at day 1 before settlement.
        vm.warp(grantExpiresAt);
        assertTrue(reqExpiresAt > grantExpiresAt);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.GrantIsExpired.selector, GRANT_RESEARCH));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), 0);
        assertFalse(settlement.isReleaseSettled(RELEASE_1));
    }

    function test_SettleResearch_RevertsWhenGrantRevokedAfterReleaseRecorded() public {
        uint64 reqExpiresAt = _fundDefaultRequest();
        _createResearchGrantAndRelease(GRANT_RESEARCH, RELEASE_1, reqExpiresAt + 1 days);

        vm.prank(PATIENT);
        consent.revokeGrant(GRANT_RESEARCH);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.GrantIsRevoked.selector, GRANT_RESEARCH));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        assertEq(settlement.creditBalances(PATIENT), 0);
        assertFalse(settlement.isReleaseSettled(RELEASE_1));
    }

    function test_SettleResearch_RevertsOnPatientResearcherOrScopeMismatch() public {
        uint64 reqExpiresAt = _fundDefaultRequest();

        // Patient mismatch (grant owned by PATIENT_2 while request names PATIENT).
        vm.prank(PATIENT_2);
        consent.grantAccess(GRANT_OTHER, RESEARCHER, IConsentManager.Purpose.Research, scopeV1, reqExpiresAt + 1 days);
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_OTHER, RESEARCHER, IConsentManager.Purpose.Research, scopeV1, receipt1);

        vm.expectRevert(
            abi.encodeWithSelector(IResearchSettlement.PatientMismatch.selector, REQUEST_1, PATIENT, PATIENT_2)
        );
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_1);

        // Researcher mismatch (grant issued to RESEARCHER_2 instead of RESEARCHER).
        vm.prank(PATIENT);
        consent.grantAccess(
            GRANT_RESEARCH, RESEARCHER_2, IConsentManager.Purpose.Research, scopeV1, reqExpiresAt + 1 days
        );
        vm.prank(GATEWAY);
        consent.recordRelease(
            RELEASE_2, GRANT_RESEARCH, RESEARCHER_2, IConsentManager.Purpose.Research, scopeV1, receipt2
        );

        vm.expectRevert(
            abi.encodeWithSelector(IResearchSettlement.ResearcherMismatch.selector, REQUEST_1, RESEARCHER, RESEARCHER_2)
        );
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, RELEASE_2);

        // Scope mismatch (grant covers scopeV2 instead of scopeV1).
        bytes32 grantWrongScope = keccak256("CareConsent:Grant:v1:wrong-scope");
        bytes32 releaseWrongScope = keccak256("CareConsent:Release:v1:wrong-scope");
        vm.prank(PATIENT);
        consent.grantAccess(
            grantWrongScope, RESEARCHER, IConsentManager.Purpose.Research, scopeV2, reqExpiresAt + 1 days
        );
        vm.prank(GATEWAY);
        consent.recordRelease(
            releaseWrongScope, grantWrongScope, RESEARCHER, IConsentManager.Purpose.Research, scopeV2, receipt2
        );

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.ScopeMismatch.selector, REQUEST_1));
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, releaseWrongScope);

        assertEq(settlement.creditBalances(PATIENT), 0);
        assertEq(settlement.creditBalances(PATIENT_2), 0);
    }

    function test_SettleResearch_RevertsOnZeroIdsAndMissingViews() public {
        assertEq(uint8(settlement.getRequestStatus(REQUEST_1)), uint8(IResearchSettlement.RequestStatus.NotFound));
        assertFalse(settlement.isReleaseSettled(RELEASE_1));

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.RequestNotFound.selector, REQUEST_1));
        settlement.getRequest(REQUEST_1);

        vm.expectRevert(abi.encodeWithSelector(IResearchSettlement.SettlementNotFound.selector, RELEASE_1));
        settlement.getSettlement(RELEASE_1);

        vm.expectRevert(IResearchSettlement.InvalidRequestId.selector);
        vm.prank(GATEWAY);
        settlement.settleResearch(bytes32(0), RELEASE_1);

        vm.expectRevert(IResearchSettlement.InvalidReleaseId.selector);
        vm.prank(GATEWAY);
        settlement.settleResearch(REQUEST_1, bytes32(0));
    }
}
