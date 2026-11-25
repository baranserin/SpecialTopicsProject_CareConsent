import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { USE_MOCK, ServiceUnavailableError, loadPatientRecords, type MockScenario } from "../api/records";
import type { Address, HealthRecord } from "../types/models";
import { EmptyState, Loading, ServiceUnavailable } from "../components/StatusMessage";
import { RecordList } from "../components/RecordList";
import { VersionPanel } from "../components/VersionPanel";
import { SelectionSummary } from "../components/SelectionSummary";

type LoadState =
  | { kind: "loading" }
  | { kind: "ready"; records: HealthRecord[] }
  | { kind: "unavailable"; detail: string };

const SCENARIOS: { value: MockScenario; label: string }[] = [
  { value: "normal", label: "Records" },
  { value: "empty", label: "Empty" },
  { value: "unavailable", label: "Service error" },
];

function initialScenario(): MockScenario {
  const v = new URLSearchParams(window.location.search).get("demo");
  return v === "empty" || v === "unavailable" ? v : "normal";
}

interface PatientRecordsProps {
  /** Owner address used for the scope commitment. */
  patientAddress: Address;
}

/** Record list, version selection and scope preview. Rendered only for an allowed viewer. */
export function PatientRecords({ patientAddress }: PatientRecordsProps) {
  const [scenario, setScenario] = useState<MockScenario>(initialScenario);
  const [load, setLoad] = useState<LoadState>({ kind: "loading" });
  const [activeKey, setActiveKey] = useState<string | null>(null);
  const [selected, setSelected] = useState<Set<string>>(() => new Set());

  // Only the latest request may update the page; an older, slower answer is ignored.
  const requestSeq = useRef(0);
  const fetchRecords = useCallback(async (s: MockScenario) => {
    const seq = ++requestSeq.current;
    setLoad({ kind: "loading" });
    try {
      const records = await loadPatientRecords(s);
      if (seq !== requestSeq.current) return;
      setLoad({ kind: "ready", records });
      setActiveKey(records[0]?.recordKey ?? null);
    } catch (e) {
      if (seq !== requestSeq.current) return;
      const detail =
        e instanceof ServiceUnavailableError ? e.message : "An unexpected error occurred while loading records.";
      setLoad({ kind: "unavailable", detail });
    }
  }, []);

  useEffect(() => {
    setSelected(new Set());
    void fetchRecords(scenario);
  }, [scenario, fetchRecords]);

  const records = load.kind === "ready" ? load.records : [];
  const activeRecord = records.find((r) => r.recordKey === activeKey) ?? null;

  const selectedCountByRecord = useMemo(() => {
    const counts = new Map<string, number>();
    for (const r of records) {
      const n = r.versions.filter((v) => selected.has(v.versionId)).length;
      if (n > 0) counts.set(r.recordKey, n);
    }
    return counts;
  }, [records, selected]);

  const toggle = (versionId: string) =>
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(versionId)) next.delete(versionId);
      else next.add(versionId);
      return next;
    });

  return (
    <>
      {USE_MOCK && (
        <div className="segmented demo-switch" role="group" aria-label="Demo state">
          {SCENARIOS.map((s) => (
            <button
              key={s.value}
              type="button"
              aria-pressed={scenario === s.value}
              className={scenario === s.value ? "is-on" : ""}
              onClick={() => setScenario(s.value)}
            >
              {s.label}
            </button>
          ))}
        </div>
      )}

      {load.kind === "loading" && <Loading label="Loading records…" />}

      {load.kind === "unavailable" && (
        <ServiceUnavailable detail={load.detail} onRetry={() => void fetchRecords(scenario)} />
      )}

      {load.kind === "ready" && records.length === 0 && (
        <EmptyState
          title="No records yet"
          detail="You have no imported health records. This is not an error: once records are imported, they appear here."
        />
      )}

      {load.kind === "ready" && records.length > 0 && (
        <div className="layout">
          <RecordList
            records={records}
            activeKey={activeKey}
            selectedCountByRecord={selectedCountByRecord}
            onOpen={setActiveKey}
          />
          {activeRecord ? (
            <VersionPanel record={activeRecord} selected={selected} onToggle={toggle} />
          ) : (
            <EmptyState title="Select a record" detail="Choose a record to see its versions." />
          )}
          <SelectionSummary
            records={records}
            selected={selected}
            patientAddress={patientAddress}
            onRemove={toggle}
            onClear={() => setSelected(new Set())}
          />
        </div>
      )}
    </>
  );
}
