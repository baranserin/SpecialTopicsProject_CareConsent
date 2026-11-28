import {
  isSelectable,
  versionLifecycle,
  type HealthRecord,
  type VersionLifecycle,
} from "../types/models";
import { RESOURCE_LABEL, formatDate, formatEpoch, shortHex } from "./format";

interface VersionPanelProps {
  record: HealthRecord;
  selected: ReadonlySet<string>;
  onToggle: (versionId: string) => void;
}

const LIFECYCLE_LABEL: Record<VersionLifecycle, string> = {
  current: "Current",
  superseded: "Superseded",
  retired: "Retired",
};

export function VersionPanel({ record, selected, onToggle }: VersionPanelProps) {
  // Newest first for reading; version numbers still count from the original.
  const ordered = record.versions.map((v, i) => ({ v, n: i + 1 })).reverse();

  return (
    <section className="panel" aria-labelledby="version-heading">
      <header className="panel-head">
        <span className={`chip chip-${record.resourceType}`}>{RESOURCE_LABEL[record.resourceType]}</span>
        <h2 id="version-heading">{record.title}</h2>
        <p className="muted small">
          Select the exact versions you may want to share. Each version is immutable; a correction
          is a new version and must be selected explicitly.
        </p>
      </header>

      <ul className="version-list">
        {ordered.map(({ v, n }) => {
          const lifecycle = versionLifecycle(v, record);
          const selectable = isSelectable(v);
          const checked = selected.has(v.versionId);
          const inputId = `ver-${v.versionId}`;
          return (
            <li key={v.versionId} className={`version-item${checked ? " is-checked" : ""}${selectable ? "" : " is-disabled"}`}>
              <input
                id={inputId}
                type="checkbox"
                checked={checked}
                disabled={!selectable}
                onChange={() => onToggle(v.versionId)}
              />
              <label htmlFor={inputId} className="version-body">
                <span className="version-top">
                  <strong>Version {n}</strong>
                  <span className={`badge badge-${lifecycle}`}>{LIFECYCLE_LABEL[lifecycle]}</span>
                  <span className="muted small">{v.status}</span>
                </span>
                <span className="version-summary">{v.summary}</span>
                <span className="version-meta muted small">
                  Recorded {formatDate(v.recordedAt)} · {v.source}
                </span>
                <span className="version-meta muted small">
                  Registered {formatEpoch(v.registeredAt)} · ID{" "}
                  <span className="mono" title={v.versionId}>{shortHex(v.versionId)}</span>
                </span>
                {lifecycle === "superseded" && (
                  <span className="note small">
                    A later correction exists. Sharing this version does not include the correction.
                  </span>
                )}
                {lifecycle === "retired" && (
                  <span className="note small">
                    Retired versions cannot be added to new sharing. The earlier on-chain commitment is kept.
                  </span>
                )}
              </label>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
