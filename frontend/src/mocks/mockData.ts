/**
 * Synthetic demonstration data. No real person, provider or clinical record is represented.
 *
 * Identifiers follow docs/contract-interface.md §3.1:
 *   versionId        = sha256("CareConsent:Version:v1:" || uuid)
 *   ciphertextDigest = sha256(encrypted envelope bytes) — here a stand-in hash, because
 *                      no real envelope exists until the backend storage pipeline is ready.
 */
import { sha256, toUtf8Bytes } from "ethers";
import {
  ZERO_BYTES32,
  type Address,
  type Bytes32,
  type FhirResourceType,
  type HealthRecord,
  type HealthRecordVersion,
} from "../types/models";

/** Anvil default accounts (docs/contract-interface.md §6). Development use only. */
export const ANVIL_ACCOUNTS = {
  admin: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  gateway: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  patient: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
  clinician: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
  researcher: "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65",
} as const satisfies Record<string, Address>;

export const MOCK_PATIENT = {
  label: "Synthetic patient P01",
  address: ANVIL_ACCOUNTS.patient as Address,
};

function versionId(uuid: string): Bytes32 {
  return sha256(toUtf8Bytes(`CareConsent:Version:v1:${uuid}`)) as Bytes32;
}

function mockDigest(uuid: string): Bytes32 {
  return sha256(toUtf8Bytes(`CareConsent:MockEnvelope:${uuid}`)) as Bytes32;
}

function epoch(iso: string): number {
  return Math.floor(Date.parse(iso) / 1000);
}

interface VersionSpec {
  uuid: string;
  recordedAt: string;
  registeredAt: string;
  status: string;
  summary: string;
  source: string;
  retired?: boolean;
}

/** Builds a version chain where each version replaces the previous one. */
function buildRecord(
  recordKey: string,
  resourceType: FhirResourceType,
  title: string,
  specs: VersionSpec[],
): HealthRecord {
  const versions: HealthRecordVersion[] = [];
  specs.forEach((spec, i) => {
    versions.push({
      versionId: versionId(spec.uuid),
      owner: MOCK_PATIENT.address,
      ciphertextDigest: mockDigest(spec.uuid),
      replacesVersionId: i === 0 ? ZERO_BYTES32 : versions[i - 1].versionId,
      registeredAt: epoch(spec.registeredAt),
      retired: spec.retired ?? false,
      resourceType,
      recordedAt: spec.recordedAt,
      status: spec.status,
      summary: spec.summary,
      source: spec.source,
    });
  });
  return { recordKey, resourceType, title, versions };
}

const CLINIC_A = "Synthetic Family Health Centre";
const CLINIC_B = "Synthetic City Hospital — Endocrinology";
const LAB = "Synthetic Central Laboratory";
const APP = "Patient-reported (synthetic)";

export const MOCK_RECORDS: HealthRecord[] = [
  buildRecord("cond-t2dm", "Condition", "Type 2 diabetes mellitus", [
    {
      uuid: "6f1b2c3a-0001-4c1e-9a10-000000000001",
      recordedAt: "2025-03-12T09:30:00Z",
      registeredAt: "2025-03-12T10:02:00Z",
      status: "provisional",
      summary: "Suspected type 2 diabetes after elevated fasting glucose.",
      source: CLINIC_A,
    },
    {
      uuid: "6f1b2c3a-0001-4c1e-9a10-000000000002",
      recordedAt: "2025-06-02T11:15:00Z",
      registeredAt: "2025-06-02T12:40:00Z",
      status: "active · confirmed",
      summary: "Diagnosis confirmed after HbA1c result; diet and metformin started.",
      source: CLINIC_B,
    },
  ]),
  buildRecord("med-metformin", "MedicationStatement", "Metformin (oral)", [
    {
      uuid: "6f1b2c3a-0002-4c1e-9a10-000000000001",
      recordedAt: "2025-06-02T11:20:00Z",
      registeredAt: "2025-06-02T12:41:00Z",
      status: "active",
      summary: "Metformin 500 mg twice daily with meals.",
      source: CLINIC_B,
    },
    {
      uuid: "6f1b2c3a-0002-4c1e-9a10-000000000002",
      recordedAt: "2025-09-15T10:05:00Z",
      registeredAt: "2025-09-15T10:30:00Z",
      status: "active",
      summary: "Dose increased to 1000 mg twice daily.",
      source: CLINIC_B,
    },
  ]),
  buildRecord("med-amoxicillin", "MedicationStatement", "Amoxicillin course (antibiotic)", [
    {
      uuid: "6f1b2c3a-0003-4c1e-9a10-000000000001",
      recordedAt: "2026-02-03T08:45:00Z",
      registeredAt: "2026-02-03T09:10:00Z",
      status: "completed",
      summary: "Amoxicillin 500 mg three times daily, 7 days (recorded with wrong start date).",
      source: CLINIC_A,
    },
    {
      uuid: "6f1b2c3a-0003-4c1e-9a10-000000000002",
      recordedAt: "2026-02-05T14:00:00Z",
      registeredAt: "2026-02-05T14:20:00Z",
      status: "completed",
      summary: "Corrected: course taken 2026-01-27 to 2026-02-02 for acute sinusitis.",
      source: CLINIC_A,
    },
  ]),
  buildRecord("allergy-sulfonamide", "AllergyIntolerance", "Sulfonamide antibiotics", [
    {
      uuid: "6f1b2c3a-0004-4c1e-9a10-000000000001",
      recordedAt: "2024-11-05T13:00:00Z",
      registeredAt: "2025-03-12T10:05:00Z",
      status: "active · low criticality",
      summary: "Skin rash reported after trimethoprim-sulfamethoxazole.",
      source: CLINIC_A,
      retired: true,
    },
    {
      uuid: "6f1b2c3a-0004-4c1e-9a10-000000000002",
      recordedAt: "2026-01-10T10:30:00Z",
      registeredAt: "2026-01-10T11:00:00Z",
      status: "active · high criticality",
      summary: "Re-assessed: widespread urticaria; avoid all sulfonamide antibiotics.",
      source: CLINIC_B,
    },
  ]),
  buildRecord("obs-hba1c", "Observation", "HbA1c (laboratory)", [
    {
      uuid: "6f1b2c3a-0005-4c1e-9a10-000000000001",
      recordedAt: "2026-04-18T07:50:00Z",
      registeredAt: "2026-04-18T12:00:00Z",
      status: "preliminary",
      summary: "HbA1c 7.8 % (preliminary result).",
      source: LAB,
    },
    {
      uuid: "6f1b2c3a-0005-4c1e-9a10-000000000002",
      recordedAt: "2026-04-19T09:10:00Z",
      registeredAt: "2026-04-19T09:30:00Z",
      status: "final",
      summary: "HbA1c 7.6 % (final, after calibration check).",
      source: LAB,
    },
  ]),
  buildRecord("obs-walking", "Observation", "Physical activity, week of 2026-10-26", [
    {
      uuid: "6f1b2c3a-0006-4c1e-9a10-000000000001",
      recordedAt: "2026-11-02T20:00:00Z",
      registeredAt: "2026-11-02T20:03:00Z",
      status: "preliminary",
      summary: "Brisk walking 90 minutes (device sync incomplete).",
      source: APP,
    },
    {
      uuid: "6f1b2c3a-0006-4c1e-9a10-000000000002",
      recordedAt: "2026-11-03T08:15:00Z",
      registeredAt: "2026-11-03T08:16:00Z",
      status: "amended",
      summary: "Brisk walking 150 minutes after full device sync.",
      source: APP,
    },
    {
      uuid: "6f1b2c3a-0006-4c1e-9a10-000000000003",
      recordedAt: "2026-11-04T19:40:00Z",
      registeredAt: "2026-11-04T19:41:00Z",
      status: "amended",
      summary: "Brisk walking 170 minutes; one manually logged session added.",
      source: APP,
    },
  ]),
];
