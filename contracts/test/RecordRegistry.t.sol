// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {RecordRegistry} from "../src/RecordRegistry.sol";
import {IRecordRegistry} from "../src/interfaces/IRecordRegistry.sol";

contract RecordRegistryTest is Test {
    RecordRegistry internal registry;

    address internal constant PATIENT_A = address(0xA11CE);
    address internal constant PATIENT_B = address(0xB0B);

    bytes32 internal constant VERSION_1 = keccak256("CareConsent:Version:v1:rec-001");
    bytes32 internal constant VERSION_2 = keccak256("CareConsent:Version:v1:rec-001-corr");

    uint64 internal constant INITIAL_TIME = 1_795_000_000;

    bytes32 internal digest1;
    bytes32 internal digest2;
    bytes32 internal tamperedDigest;

    function setUp() public {
        vm.warp(INITIAL_TIME);
        registry = new RecordRegistry();
        digest1 = sha256("encrypted-envelope-bytes-v1");
        digest2 = sha256("encrypted-envelope-bytes-v2");
        tamperedDigest = sha256("mutated-ciphertext-bytes");
    }

    function test_RegisterInitialVersion_SucceedsAndEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit IRecordRegistry.VersionRegistered(VERSION_1, PATIENT_A, digest1, bytes32(0), INITIAL_TIME);

        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        assertTrue(registry.versionExists(VERSION_1));
        assertEq(registry.ownerOf(VERSION_1), PATIENT_A);
        assertTrue(registry.verifyDigest(VERSION_1, digest1));

        IRecordRegistry.RecordVersion memory stored = registry.getVersion(VERSION_1);
        assertEq(stored.owner, PATIENT_A);
        assertEq(stored.ciphertextDigest, digest1);
        assertEq(stored.replacesVersionId, bytes32(0));
        assertEq(stored.registeredAt, INITIAL_TIME);
        assertFalse(stored.retired);
    }

    function test_RegisterCorrectionVersion_PreservesOriginalCommitment() public {
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        uint64 correctionTime = INITIAL_TIME + 3600;
        vm.warp(correctionTime);

        vm.expectEmit(true, true, true, true);
        emit IRecordRegistry.VersionRegistered(VERSION_2, PATIENT_A, digest2, VERSION_1, correctionTime);

        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_2, digest2, VERSION_1);

        IRecordRegistry.RecordVersion memory v1 = registry.getVersion(VERSION_1);
        IRecordRegistry.RecordVersion memory v2 = registry.getVersion(VERSION_2);

        assertEq(v1.ciphertextDigest, digest1);
        assertEq(v1.replacesVersionId, bytes32(0));
        assertFalse(v1.retired);

        assertEq(v2.owner, PATIENT_A);
        assertEq(v2.ciphertextDigest, digest2);
        assertEq(v2.replacesVersionId, VERSION_1);
        assertEq(v2.registeredAt, correctionTime);
        assertFalse(v2.retired);

        assertTrue(registry.verifyDigest(VERSION_1, digest1));
        assertTrue(registry.verifyDigest(VERSION_2, digest2));
    }

    function test_RegisterVersion_RevertsOnZeroVersionId() public {
        vm.expectRevert(IRecordRegistry.InvalidVersionId.selector);
        vm.prank(PATIENT_A);
        registry.registerVersion(bytes32(0), digest1, bytes32(0));
    }

    function test_RegisterVersion_RevertsOnZeroCiphertextDigest() public {
        vm.expectRevert(IRecordRegistry.InvalidCiphertextDigest.selector);
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, bytes32(0), bytes32(0));
    }

    function test_RegisterVersion_RevertsOnDuplicateVersionId() public {
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.VersionAlreadyRegistered.selector, VERSION_1));
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest2, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.VersionAlreadyRegistered.selector, VERSION_1));
        vm.prank(PATIENT_B);
        registry.registerVersion(VERSION_1, digest2, bytes32(0));
    }

    function test_RegisterVersion_RevertsWhenReplacedVersionMissing() public {
        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.ReplacedVersionNotFound.selector, VERSION_1));
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_2, digest2, VERSION_1);
    }

    function test_RegisterVersion_RevertsWhenReplacingAnotherPatientsVersion() public {
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.NotVersionOwner.selector, VERSION_1, PATIENT_B));
        vm.prank(PATIENT_B);
        registry.registerVersion(VERSION_2, digest2, VERSION_1);
    }

    function test_RetireVersion_MarksRetiredAndPreservesDigest() public {
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        uint64 retireTime = INITIAL_TIME + 7200;
        vm.warp(retireTime);

        vm.expectEmit(true, true, false, true);
        emit IRecordRegistry.VersionRetired(VERSION_1, PATIENT_A, retireTime);

        vm.prank(PATIENT_A);
        registry.retireVersion(VERSION_1);

        IRecordRegistry.RecordVersion memory stored = registry.getVersion(VERSION_1);
        assertTrue(stored.retired);
        assertEq(stored.ciphertextDigest, digest1);
        assertTrue(registry.verifyDigest(VERSION_1, digest1));
    }

    function test_RetireVersion_RevertsWhenMissing() public {
        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.VersionNotFound.selector, VERSION_1));
        vm.prank(PATIENT_A);
        registry.retireVersion(VERSION_1);
    }

    function test_RetireVersion_RevertsWhenCallerNotOwner() public {
        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.NotVersionOwner.selector, VERSION_1, PATIENT_B));
        vm.prank(PATIENT_B);
        registry.retireVersion(VERSION_1);
    }

    function test_RetireVersion_RevertsWhenAlreadyRetired() public {
        vm.startPrank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));
        registry.retireVersion(VERSION_1);

        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.VersionAlreadyRetired.selector, VERSION_1));
        registry.retireVersion(VERSION_1);
        vm.stopPrank();
    }

    function test_GetVersion_RevertsWhenMissing() public {
        vm.expectRevert(abi.encodeWithSelector(IRecordRegistry.VersionNotFound.selector, VERSION_1));
        registry.getVersion(VERSION_1);
    }

    function test_VerifyDigest_ReturnsFalseForTamperedZeroOrUnknownVersion() public {
        assertFalse(registry.verifyDigest(VERSION_1, digest1));
        assertEq(registry.ownerOf(VERSION_1), address(0));

        vm.prank(PATIENT_A);
        registry.registerVersion(VERSION_1, digest1, bytes32(0));

        assertFalse(registry.verifyDigest(VERSION_1, tamperedDigest));
        assertFalse(registry.verifyDigest(VERSION_1, bytes32(0)));
    }
}
