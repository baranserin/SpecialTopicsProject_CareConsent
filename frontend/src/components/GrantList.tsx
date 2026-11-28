import { useCallback, useEffect, useState } from "react";
import { listGrants, revokeGrant, type GrantRow } from "../chain/grants";
import type { TxState } from "../chain/transactions";
import { GRANT_STATUS_LABEL, GrantStatus, PURPOSE_LABEL, type Address, type Bytes32 } from "../types/models";
import { formatEpoch, shortHex } from "./format";
import { EmptyState, Loading, ServiceUnavailable } from "./StatusMessage";
import { TxProgress } from "./TxProgress";

type LoadState =
  | { kind: "loading" }
  | { kind: "ready"; rows: GrantRow[] }
  | { kind: "unavailable"; detail: string };

/** P4: the patient's grants with their chain status, and revoke for active ones. */
export function GrantList({ patient, refreshKey }: { patient: Address; refreshKey: number }) {
  const [load, setLoad] = useState<LoadState>({ kind: "loading" });
  const [confirming, setConfirming] = useState<Bytes32 | null>(null);
  const [tx, setTx] = useState<TxState>({ phase: "idle" });

  const refresh = useCallback(async () => {
    setLoad({ kind: "loading" });
    try {
      const { rows } = await listGrants(patient);
      setLoad({ kind: "ready", rows });
    } catch {
      setLoad({
        kind: "unavailable",
        detail: "The grants could not be read from the chain. Check that Anvil is running and the contracts are deployed.",
      });
    }
  }, [patient]);

  useEffect(() => {
    void refresh();
  }, [refresh, refreshKey]);

  async function revoke(id: Bytes32) {
    const result = await revokeGrant(id, patient, setTx);
    if (result.phase === "confirmed") {
      setConfirming(null);
      await refresh();
    }
  }

  if (load.kind === "loading") return <Loading label="Loading grants…" />;
  if (load.kind === "unavailable") return <ServiceUnavailable detail={load.detail} onRetry={() => void refresh()} />;
  if (load.rows.length === 0) {
    return (
      <EmptyState
        title="No grants yet"
        detail="You have not shared anything. This is not an error: grants you create from the Records page appear here."
      />
    );
  }

  const busy = tx.phase === "awaiting-signature" || tx.phase === "pending";

  return (
    <section className="panel" aria-labelledby="grants-heading">
      <header className="panel-head row">
        <h2 id="grants-heading">My grants ({load.rows.length})</h2>
        <button type="button" className="btn btn-outline btn-sm" onClick={() => void refresh()} disabled={busy}>
          Refresh
        </button>
      </header>
      <ul className="grant-list">
        {load.rows.map(({ grant, status }) => (
          <li key={grant.grantId} className="grant-item">
            <div className="row">
              <span className="mono" title={grant.grantId}>{shortHex(grant.grantId, 10, 6)}</span>
              <span className={`badge badge-${GRANT_STATUS_LABEL[status].toLowerCase()}`}>
                {GRANT_STATUS_LABEL[status]}
              </span>
            </div>
            <dl className="kv small">
              <dt>Recipient</dt>
              <dd className="mono" title={grant.grantee}>{shortHex(grant.grantee, 8, 6)}</dd>
              <dt>Purpose</dt>
              <dd>{PURPOSE_LABEL[grant.purpose]}</dd>
              <dt>Scope</dt>
              <dd className="mono" title={grant.scopeCommitment}>{shortHex(grant.scopeCommitment, 10, 8)}</dd>
              <dt>Granted</dt>
              <dd>{formatEpoch(grant.grantedAt)}</dd>
              <dt>{status === GrantStatus.Revoked ? "Revoked" : "Expires"}</dt>
              <dd>{formatEpoch(status === GrantStatus.Revoked ? grant.revokedAt : grant.expiresAt)}</dd>
            </dl>

            {status === GrantStatus.Active && confirming !== grant.grantId && (
              <button type="button" className="btn btn-outline btn-sm" onClick={() => { setTx({ phase: "idle" }); setConfirming(grant.grantId); }}>
                Revoke access
              </button>
            )}

            {confirming === grant.grantId && (
              <div className="banner banner-warn" role="alertdialog" aria-label="Confirm revocation">
                <p className="small">
                  After the revocation is confirmed, the gateway refuses every new request for this grant, including a
                  prepared response that has not been released yet. It cannot recall data already released.
                </p>
                <TxProgress state={tx} />
                <div className="row">
                  <button type="button" className="btn btn-outline btn-sm" onClick={() => setConfirming(null)} disabled={busy}>
                    Cancel
                  </button>
                  <button type="button" className="btn btn-sm" onClick={() => void revoke(grant.grantId)} disabled={busy}>
                    {busy ? "Working…" : "Revoke in MetaMask"}
                  </button>
                </div>
              </div>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}
