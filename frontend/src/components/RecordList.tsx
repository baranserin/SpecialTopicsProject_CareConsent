import type { HealthRecord } from "../types/models";
import { RESOURCE_LABEL, formatDate } from "./format";

interface RecordListProps {
  records: HealthRecord[];
  activeKey: string | null;
  selectedCountByRecord: Map<string, number>;
  onOpen: (recordKey: string) => void;
}

export function RecordList({ records, activeKey, selectedCountByRecord, onOpen }: RecordListProps) {
  return (
    <ul className="record-list" aria-label="Health records">
      {records.map((record) => {
        const latest = record.versions[record.versions.length - 1];
        const selected = selectedCountByRecord.get(record.recordKey) ?? 0;
        const active = record.recordKey === activeKey;
        return (
          <li key={record.recordKey}>
            <button
              type="button"
              className={`record-item${active ? " is-active" : ""}`}
              aria-current={active ? "true" : undefined}
              onClick={() => onOpen(record.recordKey)}
            >
              <span className={`chip chip-${record.resourceType}`}>
                {RESOURCE_LABEL[record.resourceType]}
              </span>
              <span className="record-title">{record.title}</span>
              <span className="record-meta">
                {record.versions.length} versions · latest {formatDate(latest.recordedAt)}
              </span>
              {selected > 0 && (
                <span className="badge badge-selected">{selected} selected</span>
              )}
            </button>
          </li>
        );
      })}
    </ul>
  );
}
