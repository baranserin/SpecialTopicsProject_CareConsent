/**
 * Frontend data models for CareConsent.
 *
 * On-chain fields mirror the Solidity structs and enums in
 * `contracts/src/interfaces/*.sol` and `docs/contract-interface.md`.
 * Off-chain fields (summaries, clinical dates, receipt details) are a draft and must be
 * aligned with the Spring Boot gateway API once it is defined.
 *
 * Privacy rule (docs/contract-interface.md §2): raw IPFS CIDs, encryption keys and
 * plaintext patient identifiers never appear in these models.
 */
import { AbiCoder, getAddress, isHexString, keccak256 } from "ethers";

// ---------------------------------------------------------------------------
// Primitive encodings
// ---------------------------------------------------------------------------

/** `bytes32` value: `0x` + 64 hex characters. */
export type Bytes32 = `0x${string}`;
/** EVM address: `0x` + 40 hex characters (checksummed when produced by ethers). */
export type Address = `0x${string}`;
/** Unix epoch seconds (UTC), matching the contracts' `uint64` timestamps. */
export type UnixSeconds = number;

export const ZERO_BYTES32: Bytes32 = `0x${"0".repeat(64)}`;

export function isBytes32(value: string): value is Bytes32 {
  return isHexString(value, 32);
}

// ---------------------------------------------------------------------------
// Enumerations (uint8 values must match the Solidity declaration order)
// ---------------------------------------------------------------------------

/** IConsentManager.Purpose */
export const Purpose = {
  None: 0,
  Treatment: 1,
  Research: 2,
} as const;
export type Purpose = (typeof Purpose)[keyof typeof Purpose];

/** IConsentManager.GrantStatus. `Pending` / `Refused` are off-chain AccessRequest states. */
export const GrantStatus = {
  NotFound: 0,
  Active: 1,
  Expired: 2,
  Revoked: 3,
} as const;
export type GrantStatus = (typeof GrantStatus)[keyof typeof GrantStatus];

/** IResearchSettlement.RequestStatus */
export const RequestStatus = {
  NotFound: 0,
  Funded: 1,
  Refused: 2,
  Settled: 3,
  Refunded: 4,
  Expired: 5,
} as const;
export type RequestStatus = (typeof RequestStatus)[keyof typeof RequestStatus];

export const PURPOSE_LABEL: Record<Purpose, string> = {
  [Purpose.None]: "None",
  [Purpose.Treatment]: "Treatment",
  [Purpose.Research]: "Research",
};

export const GRANT_STATUS_LABEL: Record<GrantStatus, string> = {
  [GrantStatus.NotFound]: "Not found",
  [GrantStatus.Active]: "Active",
  [GrantStatus.Expired]: "Expired",
  [GrantStatus.Revoked]: "Revoked",
};

export const REQUEST_STATUS_LABEL: Record<RequestStatus, string> = {
  [RequestStatus.NotFound]: "Not found",
  [RequestStatus.Funded]: "Funded",
  [RequestStatus.Refused]: "Refused",
  [RequestStatus.Settled]: "Settled",
  [RequestStatus.Refunded]: "Refunded",
  [RequestStatus.Expired]: "Expired",
};

// ---------------------------------------------------------------------------
// Health records
// ---------------------------------------------------------------------------

export type FhirResourceType =
  | "Condition"
  | "MedicationStatement"
  | "AllergyIntolerance"
  | "Observation";

/** On-chain part of a version: IRecordRegistry.RecordVersion */
export interface RecordVersionOnChain {
  owner: Address;
  ciphertextDigest: Bytes32;
  /** `ZERO_BYTES32` for an initial version. */
  replacesVersionId: Bytes32;
  registeredAt: UnixSeconds;
  retired: boolean;
}

/** One immutable record version as shown to its owner (on-chain commitment + decrypted display fields). */
export interface HealthRecordVersion extends RecordVersionOnChain {
  versionId: Bytes32;
  resourceType: FhirResourceType;
  /** Clinical date of the source resource (ISO 8601, UTC). */
  recordedAt: string;
  /** FHIR status of the resource, e.g. "active", "completed", "final", "entered-in-error". */
  status: string;
  /** Short human-readable summary of this version. */
  summary: string;
  /** Synthetic source provider label. */
  source: string;
}

/** A logical record: the chain of versions of one FHIR resource, oldest first. */
export interface HealthRecord {
  /** Local display key; not an on-chain identifier. */
  recordKey: string;
  resourceType: FhirResourceType;
  title: string;
  versions: HealthRecordVersion[];
}

/**
 * - `current`: latest non-retired version of the record
 * - `superseded`: replaced by a later correction (still historically identifiable)
 * - `retired`: removed from new selection; its commitment stays on chain
 */
export type VersionLifecycle = "current" | "superseded" | "retired";

export function versionLifecycle(
  version: HealthRecordVersion,
  record: HealthRecord,
): VersionLifecycle {
  if (version.retired) return "retired";
  const replaced = record.versions.some(
    (v) => v.replacesVersionId.toLowerCase() === version.versionId.toLowerCase(),
  );
  return replaced ? "superseded" : "current";
}

/** Retired versions cannot be added to a new grant scope. */
export function isSelectable(version: HealthRecordVersion): boolean {
  return !version.retired;
}

// ---------------------------------------------------------------------------
// Consent grants and release receipts
// ---------------------------------------------------------------------------

/** IConsentManager.ConsentGrant plus its `grantId`. */
export interface AccessGrant {
  grantId: Bytes32;
  owner: Address;
  grantee: Address;
  purpose: Purpose;
  scopeCommitment: Bytes32;
  grantedAt: UnixSeconds;
  expiresAt: UnixSeconds;
  revoked: boolean;
  revokedAt: UnixSeconds;
}

/**
 * Same rule as `ConsentManager.getGrantStatus`: revocation takes precedence, and a grant
 * is expired when `now >= expiresAt` (authorisation requires `now < expiresAt`).
 * `now` should be the latest confirmed block timestamp, not the browser clock.
 */
export function grantStatusAt(grant: AccessGrant | undefined, now: UnixSeconds): GrantStatus {
  if (!grant) return GrantStatus.NotFound;
  if (grant.revoked) return GrantStatus.Revoked;
  if (now >= grant.expiresAt) return GrantStatus.Expired;
  return GrantStatus.Active;
}

/** Outcome of a gateway release attempt, as described by the private off-chain receipt. */
export type ReleaseOutcome = "released" | "delivery-unconfirmed";

/**
 * A release receipt: the on-chain IConsentManager.ReleaseCommitment plus the decrypted
 * off-chain receipt details that only the patient sees. The receipt records an authorised
 * release attempt; it does not prove that a person read the data.
 */
export interface AccessReceipt {
  releaseId: Bytes32;
  // on-chain ReleaseCommitment
  grantId: Bytes32;
  gateway: Address;
  grantee: Address;
  purpose: Purpose;
  receiptCommitment: Bytes32;
  recordedAt: UnixSeconds;
  // off-chain receipt details (draft, pending the gateway API)
  details?: {
    versionIds: Bytes32[];
    releasedAt: UnixSeconds;
    outcome: ReleaseOutcome;
  };
}

// ---------------------------------------------------------------------------
// Scope commitment (docs/contract-interface.md §3.1)
// ---------------------------------------------------------------------------

export class ScopeCommitmentError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ScopeCommitmentError";
  }
}

/**
 * Validates and sorts version identifiers strictly ascending by unsigned 256-bit value.
 * Rejects an empty list, malformed or zero identifiers, and duplicates.
 */
export function sortVersionIds(versionIds: readonly string[]): Bytes32[] {
  if (versionIds.length === 0) {
    throw new ScopeCommitmentError("Select at least one record version.");
  }
  const normalised = versionIds.map((id) => {
    if (!isBytes32(id)) throw new ScopeCommitmentError(`Not a bytes32 value: ${id}`);
    if (BigInt(id) === 0n) throw new ScopeCommitmentError("Zero version identifier is not allowed.");
    return id.toLowerCase() as Bytes32;
  });
  normalised.sort((a, b) => {
    const x = BigInt(a);
    const y = BigInt(b);
    return x < y ? -1 : x > y ? 1 : 0;
  });
  for (let i = 1; i < normalised.length; i++) {
    if (normalised[i] === normalised[i - 1]) {
      throw new ScopeCommitmentError(`Duplicate version identifier: ${normalised[i]}`);
    }
  }
  return normalised;
}

/** `keccak256(abi.encode(patientAddress, sortedVersionIds))` */
export function computeScopeCommitment(
  patientAddress: string,
  versionIds: readonly string[],
): Bytes32 {
  const sorted = sortVersionIds(versionIds);
  const encoded = AbiCoder.defaultAbiCoder().encode(
    ["address", "bytes32[]"],
    [getAddress(patientAddress), sorted],
  );
  return keccak256(encoded) as Bytes32;
}
