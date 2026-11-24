// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ConsentManager} from "../src/ConsentManager.sol";
import {IConsentManager} from "../src/interfaces/IConsentManager.sol";

contract ConsentManagerTest is Test {
    ConsentManager internal consent;

    address internal constant ADMIN = address(0xAD01);
    address internal constant GATEWAY = address(0x6A7E);
    address internal constant GATEWAY_2 = address(0x6A7F);
    address internal constant PATIENT = address(0xA11CE);
    address internal constant CLINICIAN_A = address(0xC11A);
    address internal constant CLINICIAN_B = address(0xC11B);
    address internal constant RESEARCHER = address(0xAE5E);
    address internal constant ATTACKER = address(0xBAD);

    bytes32 internal constant VERSION_1 = keccak256("CareConsent:Version:v1:med-001");
    bytes32 internal constant VERSION_2 = keccak256("CareConsent:Version:v1:med-001-corr");
    bytes32 internal constant GRANT_1 = keccak256("CareConsent:Grant:v1:grant-001");
    bytes32 internal constant GRANT_2 = keccak256("CareConsent:Grant:v1:grant-002");
    bytes32 internal constant RELEASE_1 = keccak256("CareConsent:Release:v1:rel-001");

    uint64 internal constant INITIAL_TIME = 1_795_000_000;
    uint64 internal constant THIRTY_DAYS = 30 days;

    bytes32 internal receipt1;
    bytes32 internal tamperedReceipt;
    bytes32 internal scopeV1Only;
    bytes32 internal scopeV1AndV2;

    function setUp() public {
        vm.warp(INITIAL_TIME);

        vm.prank(ADMIN);
        consent = new ConsentManager(GATEWAY);

        receipt1 = sha256("encrypted-release-receipt-bytes-1");
        tamperedReceipt = sha256("tampered-receipt-bytes");
        scopeV1Only = _computeScopeCommitment(PATIENT, VERSION_1);
        scopeV1AndV2 = _computeTwoVersionScopeCommitment(PATIENT, VERSION_1, VERSION_2);
    }

    function _computeScopeCommitment(address patient, bytes32 v1) internal pure returns (bytes32) {
        bytes32[] memory versions = new bytes32[](1);
        versions[0] = v1;
        return keccak256(abi.encode(patient, versions));
    }

    function _computeTwoVersionScopeCommitment(address patient, bytes32 v1, bytes32 v2)
        internal
        pure
        returns (bytes32)
    {
        bytes32[] memory versions = new bytes32[](2);
        if (v1 < v2) {
            versions[0] = v1;
            versions[1] = v2;
        } else {
            versions[0] = v2;
            versions[1] = v1;
        }
        return keccak256(abi.encode(patient, versions));
    }

    function _createDefaultTreatmentGrant() internal returns (uint64 expiresAt) {
        expiresAt = INITIAL_TIME + THIRTY_DAYS;
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, expiresAt);
    }

    // -------------------------------------------------------------------------
    // Admin & Gateway Allowlist Tests
    // -------------------------------------------------------------------------

    function test_Constructor_AuthorizesInitialGatewayAndSetsAdmin() public view {
        assertEq(consent.admin(), ADMIN);
        assertTrue(consent.authorizedGateways(GATEWAY));
        assertFalse(consent.authorizedGateways(GATEWAY_2));
    }

    function test_Constructor_AllowsZeroInitialGateway() public {
        vm.prank(ADMIN);
        ConsentManager noInitialGateway = new ConsentManager(address(0));
        assertEq(noInitialGateway.admin(), ADMIN);
        assertFalse(noInitialGateway.authorizedGateways(GATEWAY));
    }

    function test_SetGatewayAuthorization_AdminCanAddAndRemoveGateway() public {
        vm.expectEmit(true, false, false, true);
        emit IConsentManager.GatewayAuthorizationUpdated(GATEWAY_2, true);

        vm.prank(ADMIN);
        consent.setGatewayAuthorization(GATEWAY_2, true);
        assertTrue(consent.authorizedGateways(GATEWAY_2));

        vm.expectEmit(true, false, false, true);
        emit IConsentManager.GatewayAuthorizationUpdated(GATEWAY_2, false);

        vm.prank(ADMIN);
        consent.setGatewayAuthorization(GATEWAY_2, false);
        assertFalse(consent.authorizedGateways(GATEWAY_2));
    }

    function test_SetGatewayAuthorization_RevertsForNonAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(IConsentManager.UnauthorizedAdmin.selector, ATTACKER));
        vm.prank(ATTACKER);
        consent.setGatewayAuthorization(GATEWAY_2, true);
    }

    function test_SetGatewayAuthorization_RevertsForZeroAddress() public {
        vm.expectRevert(IConsentManager.InvalidGatewayAddress.selector);
        vm.prank(ADMIN);
        consent.setGatewayAuthorization(address(0), true);
    }

    // -------------------------------------------------------------------------
    // Grant Creation Tests
    // -------------------------------------------------------------------------

    function test_GrantAccess_TreatmentGrantSucceedsAndEmitsEvent() public {
        uint64 expiresAt = INITIAL_TIME + THIRTY_DAYS;

        vm.expectEmit(true, true, true, true);
        emit IConsentManager.GrantCreated(
            GRANT_1, PATIENT, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, expiresAt, INITIAL_TIME
        );

        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, expiresAt);

        IConsentManager.ConsentGrant memory grant = consent.getGrant(GRANT_1);
        assertEq(grant.owner, PATIENT);
        assertEq(grant.grantee, CLINICIAN_A);
        assertEq(uint8(grant.purpose), uint8(IConsentManager.Purpose.Treatment));
        assertEq(grant.scopeCommitment, scopeV1Only);
        assertEq(grant.grantedAt, INITIAL_TIME);
        assertEq(grant.expiresAt, expiresAt);
        assertFalse(grant.revoked);
        assertEq(grant.revokedAt, 0);
        assertEq(uint8(consent.getGrantStatus(GRANT_1)), uint8(IConsentManager.GrantStatus.Active));
    }

    function test_GrantAccess_ResearchGrantSucceedsAndEmitsEvent() public {
        uint64 expiresAt = INITIAL_TIME + 7 days;

        vm.expectEmit(true, true, true, true);
        emit IConsentManager.GrantCreated(
            GRANT_2, PATIENT, RESEARCHER, IConsentManager.Purpose.Research, scopeV1Only, expiresAt, INITIAL_TIME
        );

        vm.prank(PATIENT);
        consent.grantAccess(GRANT_2, RESEARCHER, IConsentManager.Purpose.Research, scopeV1Only, expiresAt);

        IConsentManager.ConsentGrant memory grant = consent.getGrant(GRANT_2);
        assertEq(uint8(grant.purpose), uint8(IConsentManager.Purpose.Research));
        assertTrue(consent.isAccessAuthorized(GRANT_2, RESEARCHER, IConsentManager.Purpose.Research, scopeV1Only));
    }

    function test_GrantAccess_RevertsOnZeroGrantId() public {
        vm.expectRevert(IConsentManager.InvalidGrantId.selector);
        vm.prank(PATIENT);
        consent.grantAccess(
            bytes32(0), CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, INITIAL_TIME + 1 days
        );
    }

    function test_GrantAccess_RevertsOnDuplicateGrantId() public {
        _createDefaultTreatmentGrant();

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantAlreadyExists.selector, GRANT_1));
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_B, IConsentManager.Purpose.Treatment, scopeV1Only, INITIAL_TIME + 1 days);
    }

    function test_GrantAccess_RevertsOnZeroGranteeOrSelfGrant() public {
        vm.expectRevert(IConsentManager.InvalidGrantee.selector);
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, address(0), IConsentManager.Purpose.Treatment, scopeV1Only, INITIAL_TIME + 1 days);

        vm.expectRevert(IConsentManager.InvalidGrantee.selector);
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, PATIENT, IConsentManager.Purpose.Treatment, scopeV1Only, INITIAL_TIME + 1 days);
    }

    function test_GrantAccess_RevertsOnPurposeNone() public {
        vm.expectRevert(IConsentManager.InvalidPurpose.selector);
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.None, scopeV1Only, INITIAL_TIME + 1 days);
    }

    function test_GrantAccess_RevertsOnZeroScopeCommitment() public {
        vm.expectRevert(IConsentManager.InvalidScopeCommitment.selector);
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, bytes32(0), INITIAL_TIME + 1 days);
    }

    function test_GrantAccess_RevertsWhenExpiryNotStrictlyInFuture() public {
        vm.expectRevert(abi.encodeWithSelector(IConsentManager.ExpiryNotInFuture.selector, INITIAL_TIME, INITIAL_TIME));
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, INITIAL_TIME);

        vm.expectRevert(
            abi.encodeWithSelector(IConsentManager.ExpiryNotInFuture.selector, INITIAL_TIME - 1, INITIAL_TIME)
        );
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, INITIAL_TIME - 1);
    }

    // -------------------------------------------------------------------------
    // Access Control Matrix Tests (isAccessAuthorized & getGrantStatus)
    // -------------------------------------------------------------------------

    function test_AccessMatrix_MissingGrantReturnsNotFoundAndFalse() public view {
        assertEq(uint8(consent.getGrantStatus(GRANT_1)), uint8(IConsentManager.GrantStatus.NotFound));
        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only));
    }

    function test_AccessMatrix_ValidTreatmentGrantAuthorizesExactTuple() public {
        _createDefaultTreatmentGrant();

        assertTrue(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only));
    }

    function test_AccessMatrix_WrongGranteeDenied() public {
        _createDefaultTreatmentGrant();

        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_B, IConsentManager.Purpose.Treatment, scopeV1Only));
        assertFalse(consent.isAccessAuthorized(GRANT_1, RESEARCHER, IConsentManager.Purpose.Treatment, scopeV1Only));
    }

    function test_AccessMatrix_TreatmentGrantDoesNotAuthorizeResearch() public {
        _createDefaultTreatmentGrant();

        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Research, scopeV1Only));
    }

    function test_AccessMatrix_ResearchGrantDoesNotAuthorizeTreatment() public {
        vm.prank(PATIENT);
        consent.grantAccess(GRANT_2, RESEARCHER, IConsentManager.Purpose.Research, scopeV1Only, INITIAL_TIME + 7 days);

        assertFalse(consent.isAccessAuthorized(GRANT_2, RESEARCHER, IConsentManager.Purpose.Treatment, scopeV1Only));
    }

    function test_AccessMatrix_ScopeMismatchOrExcludedCorrectionVersionDenied() public {
        _createDefaultTreatmentGrant();

        // Grant only committed to VERSION_1; adding VERSION_2 (or requesting an unselected record) must fail.
        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1AndV2));
        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, bytes32(0)));
        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.None, scopeV1Only));
    }

    function test_AccessMatrix_StrictExpiryBoundary_TMinusOnePassesAndTFails() public {
        uint64 expiresAt = _createDefaultTreatmentGrant();

        // T - 1 second: strictly less than expiresAt -> Active & authorized.
        vm.warp(expiresAt - 1);
        assertEq(uint8(consent.getGrantStatus(GRANT_1)), uint8(IConsentManager.GrantStatus.Active));
        assertTrue(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only));

        // Exactly T: block.timestamp == expiresAt -> Expired & denied.
        vm.warp(expiresAt);
        assertEq(uint8(consent.getGrantStatus(GRANT_1)), uint8(IConsentManager.GrantStatus.Expired));
        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only));
    }

    function test_GetGrant_RevertsWhenNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantNotFound.selector, GRANT_1));
        consent.getGrant(GRANT_1);
    }

    // -------------------------------------------------------------------------
    // Revocation Tests
    // -------------------------------------------------------------------------

    function test_RevokeGrant_OwnerRevokesActiveGrantAndBlocksAccess() public {
        _createDefaultTreatmentGrant();

        uint64 revokeTime = INITIAL_TIME + 600;
        vm.warp(revokeTime);

        vm.expectEmit(true, true, false, true);
        emit IConsentManager.GrantRevoked(GRANT_1, PATIENT, revokeTime);

        vm.prank(PATIENT);
        consent.revokeGrant(GRANT_1);

        IConsentManager.ConsentGrant memory grant = consent.getGrant(GRANT_1);
        assertTrue(grant.revoked);
        assertEq(grant.revokedAt, revokeTime);
        assertEq(uint8(consent.getGrantStatus(GRANT_1)), uint8(IConsentManager.GrantStatus.Revoked));
        assertFalse(consent.isAccessAuthorized(GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only));
    }

    function test_RevokeGrant_RevertsForNonOwner() public {
        _createDefaultTreatmentGrant();

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.NotGrantOwner.selector, GRANT_1, CLINICIAN_A));
        vm.prank(CLINICIAN_A);
        consent.revokeGrant(GRANT_1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.NotGrantOwner.selector, GRANT_1, GATEWAY));
        vm.prank(GATEWAY);
        consent.revokeGrant(GRANT_1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.NotGrantOwner.selector, GRANT_1, ATTACKER));
        vm.prank(ATTACKER);
        consent.revokeGrant(GRANT_1);
    }

    function test_RevokeGrant_RevertsForMissingGrant() public {
        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantNotFound.selector, GRANT_1));
        vm.prank(PATIENT);
        consent.revokeGrant(GRANT_1);
    }

    function test_RevokeGrant_RevertsWhenAlreadyRevoked() public {
        _createDefaultTreatmentGrant();

        vm.startPrank(PATIENT);
        consent.revokeGrant(GRANT_1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantAlreadyRevoked.selector, GRANT_1));
        consent.revokeGrant(GRANT_1);
        vm.stopPrank();
    }

    function test_RevokeGrant_RevertsWhenAlreadyExpired() public {
        uint64 expiresAt = _createDefaultTreatmentGrant();
        vm.warp(expiresAt);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantAlreadyExpired.selector, GRANT_1));
        vm.prank(PATIENT);
        consent.revokeGrant(GRANT_1);
    }

    // -------------------------------------------------------------------------
    // Release Receipt Anchoring & Fail-Closed Enforcement Tests
    // -------------------------------------------------------------------------

    function test_RecordRelease_AuthorizedGatewayAnchorsReceiptAndReconciles() public {
        _createDefaultTreatmentGrant();
        uint64 releaseTime = INITIAL_TIME + 120;
        vm.warp(releaseTime);

        vm.expectEmit(true, true, true, true);
        emit IConsentManager.ReleaseRecorded(
            RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, receipt1, GATEWAY, releaseTime
        );

        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        assertTrue(consent.releaseExists(RELEASE_1));
        assertTrue(consent.verifyReceiptCommitment(RELEASE_1, receipt1));
        assertFalse(consent.verifyReceiptCommitment(RELEASE_1, tamperedReceipt));

        IConsentManager.ReleaseCommitment memory stored = consent.getRelease(RELEASE_1);
        assertEq(stored.grantId, GRANT_1);
        assertEq(stored.gateway, GATEWAY);
        assertEq(stored.grantee, CLINICIAN_A);
        assertEq(uint8(stored.purpose), uint8(IConsentManager.Purpose.Treatment));
        assertEq(stored.receiptCommitment, receipt1);
        assertEq(stored.recordedAt, releaseTime);
    }

    function test_RecordRelease_RevertsForUnauthorizedCallerAndDeauthorizedGateway() public {
        _createDefaultTreatmentGrant();

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.UnauthorizedGateway.selector, PATIENT));
        vm.prank(PATIENT);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.UnauthorizedGateway.selector, CLINICIAN_A));
        vm.prank(CLINICIAN_A);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        vm.prank(ADMIN);
        consent.setGatewayAuthorization(GATEWAY, false);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.UnauthorizedGateway.selector, GATEWAY));
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        assertFalse(consent.releaseExists(RELEASE_1));
    }

    function test_RecordRelease_RevertsOnZeroIdsOrDuplicateReleaseId() public {
        _createDefaultTreatmentGrant();

        vm.expectRevert(IConsentManager.InvalidReleaseId.selector);
        vm.prank(GATEWAY);
        consent.recordRelease(
            bytes32(0), GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1
        );

        vm.expectRevert(IConsentManager.InvalidReceiptCommitment.selector);
        vm.prank(GATEWAY);
        consent.recordRelease(
            RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, bytes32(0)
        );

        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.ReleaseAlreadyRecorded.selector, RELEASE_1));
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);
    }

    function test_RecordRelease_RevertsWhenGrantMissing() public {
        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantNotFound.selector, GRANT_1));
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);
        assertFalse(consent.releaseExists(RELEASE_1));
    }

    function test_RecordRelease_RevertsOnConcurrentRevokeBeforeFinalCheck() public {
        _createDefaultTreatmentGrant();

        // Simulate patient revoking the grant before the gateway anchors the prepared release.
        vm.prank(PATIENT);
        consent.revokeGrant(GRANT_1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantIsRevoked.selector, GRANT_1));
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);
        assertFalse(consent.releaseExists(RELEASE_1));
    }

    function test_RecordRelease_RevertsAtExactExpiryBoundary() public {
        uint64 expiresAt = _createDefaultTreatmentGrant();
        vm.warp(expiresAt);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.GrantIsExpired.selector, GRANT_1));
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);
        assertFalse(consent.releaseExists(RELEASE_1));
    }

    function test_RecordRelease_RevertsOnGranteePurposeOrScopeMismatch() public {
        _createDefaultTreatmentGrant();

        vm.expectRevert(
            abi.encodeWithSelector(IConsentManager.GranteeMismatch.selector, GRANT_1, CLINICIAN_A, CLINICIAN_B)
        );
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_B, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IConsentManager.PurposeMismatch.selector,
                GRANT_1,
                IConsentManager.Purpose.Treatment,
                IConsentManager.Purpose.Research
            )
        );
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Research, scopeV1Only, receipt1);

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.ScopeMismatch.selector, GRANT_1));
        vm.prank(GATEWAY);
        consent.recordRelease(
            RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1AndV2, receipt1
        );

        assertFalse(consent.releaseExists(RELEASE_1));
    }

    function test_VerifyReceiptCommitment_AndGetRelease_HandleMissingAndZero() public {
        assertFalse(consent.releaseExists(RELEASE_1));
        assertFalse(consent.verifyReceiptCommitment(RELEASE_1, receipt1));

        vm.expectRevert(abi.encodeWithSelector(IConsentManager.ReleaseNotFound.selector, RELEASE_1));
        consent.getRelease(RELEASE_1);

        _createDefaultTreatmentGrant();
        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        assertFalse(consent.verifyReceiptCommitment(RELEASE_1, bytes32(0)));
    }

    function test_HistoricalReceiptRemainsVerifiableAfterGrantRevokedOrExpired() public {
        uint64 expiresAt = _createDefaultTreatmentGrant();

        vm.prank(GATEWAY);
        consent.recordRelease(RELEASE_1, GRANT_1, CLINICIAN_A, IConsentManager.Purpose.Treatment, scopeV1Only, receipt1);

        // Patient revokes grant afterwards; future releases fail, historical receipt stays verifiable.
        vm.prank(PATIENT);
        consent.revokeGrant(GRANT_1);

        assertTrue(consent.releaseExists(RELEASE_1));
        assertTrue(consent.verifyReceiptCommitment(RELEASE_1, receipt1));
        assertEq(consent.getRelease(RELEASE_1).receiptCommitment, receipt1);

        // Even after expiry time passes, historical receipt remains intact while status shows Revoked.
        vm.warp(expiresAt + 100);
        assertEq(uint8(consent.getGrantStatus(GRANT_1)), uint8(IConsentManager.GrantStatus.Revoked));
        assertTrue(consent.verifyReceiptCommitment(RELEASE_1, receipt1));
    }
}
