import { useMemo } from "react";
import { computeScopeCommitment, type Address, type HealthRecord } from "../types/models";
import { shortHex } from "./format";

interface SelectionSummaryProps {
  records: HealthRecord[];
  selected: ReadonlySet<string>;
  patientAddress: Address;
  onRemove: (versionId: string) => void;
  onClear: () => void;
}

export function SelectionSummary({
  records,
  selected,
  patientAddress,
  onRemove,
  onClear,
}: SelectionSummaryProps) {
  const items = useMemo(
    () =>
      records.flatMap((record) =>
        record.versions
          .map((v, i) => ({ record, version: v, n: i + 1 }))
          .filter(({ version }) => selected.has(version.versionId)),
      ),
    [records, selected],
  );

  const scope = useMemo((): { value: string } | { error: string } | null => {
    if (items.length === 0) return null;
    try {
      return { value: computeScopeCommitment(patientAddress, items.map((i) => i.version.versionId)) };
    } catch (e) {
      return { error: e instanceof Error ? e.message : String(e) };
    }
  }, [items, patientAddress]);

  return (
    <aside className="panel selection" aria-labelledby="selection-heading">
      <header className="panel-head row">
        <h2 id="selection-heading">Selected versions ({items.length})</h2>
        {items.length > 0 && (
          <button type="button" className="btn btn-outline btn-sm" onClick={onClear}>
            Clear
          </button>
        )}
      </header>

      {items.length === 0 ? (
        <p className="muted small">No versions selected. Open a record and tick the versions to include.</p>
      ) : (
        <>
          <ul className="selection-list">
            {items.map(({ record, version, n }) => (
              <li key={version.versionId}>
                <span>
                  {record.title} <span className="muted">· v{n}</span>
                </span>
                <button
                  type="button"
                  className="link-btn"
                  onClick={() => onRemove(version.versionId)}
                  aria-label={`Remove ${record.title} version ${n}`}
                >
                  Remove
                </button>
              </li>
            ))}
          </ul>

          <div className="scope">
            <p className="small muted">
              Scope commitment (what the consent contract will store instead of the version list):
            </p>
            {scope && "value" in scope ? (
              <p className="mono scope-value" title={scope.value}>
                {shortHex(scope.value, 10, 8)}
              </p>
            ) : (
              <p className="small error-text">{scope?.error}</p>
            )}
          </div>

          <p className="small muted">
            Choosing a recipient, purpose and expiry comes in the next step (grant creation).
          </p>
        </>
      )}
    </aside>
  );
}
