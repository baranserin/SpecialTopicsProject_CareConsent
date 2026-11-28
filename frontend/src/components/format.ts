import type { FhirResourceType } from "../types/models";

const DATE_FMT = new Intl.DateTimeFormat("en-GB", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  timeZone: "UTC",
});

const DATE_TIME_FMT = new Intl.DateTimeFormat("en-GB", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  timeZone: "UTC",
});

export function formatDate(iso: string): string {
  return DATE_FMT.format(new Date(iso));
}

export function formatEpoch(seconds: number): string {
  return `${DATE_TIME_FMT.format(new Date(seconds * 1000))} UTC`;
}

/** 0x1234…abcd — the full value should be available via `title`. */
export function shortHex(value: string, head = 6, tail = 4): string {
  return value.length <= head + tail + 1 ? value : `${value.slice(0, head)}…${value.slice(-tail)}`;
}

export const RESOURCE_LABEL: Record<FhirResourceType, string> = {
  Condition: "Condition",
  MedicationStatement: "Medication",
  AllergyIntolerance: "Allergy",
  Observation: "Observation",
};
