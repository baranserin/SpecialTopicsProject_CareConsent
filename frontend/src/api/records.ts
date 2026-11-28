/**
 * Record data access. Only the mock source exists today; the gateway API will be added once
 * its endpoints are agreed with the backend owner.
 */
import { MOCK_RECORDS } from "../mocks/mockData";
import type { HealthRecord } from "../types/models";

export const USE_MOCK = import.meta.env.VITE_USE_MOCK !== "false";

/** Demo scenarios, so the empty and unavailable states (S12) can be checked by hand. */
export type MockScenario = "normal" | "empty" | "unavailable";

/** Distinguishes a dependency failure from an empty but valid answer. */
export class ServiceUnavailableError extends Error {
  constructor(message = "The record service is unavailable.") {
    super(message);
    this.name = "ServiceUnavailableError";
  }
}

const MOCK_LATENCY_MS = 400;

export async function loadPatientRecords(scenario: MockScenario = "normal"): Promise<HealthRecord[]> {
  if (!USE_MOCK) {
    // Gateway endpoint not defined yet; fail closed rather than show invented data.
    throw new ServiceUnavailableError("The gateway API is not connected yet (VITE_USE_MOCK=false).");
  }
  await new Promise((resolve) => setTimeout(resolve, MOCK_LATENCY_MS));
  if (scenario === "unavailable") throw new ServiceUnavailableError();
  if (scenario === "empty") return [];
  return MOCK_RECORDS;
}
