import { useState } from "react";
import { getAddress, isAddress } from "ethers";
import { ANVIL_ACCOUNTS } from "../mocks/mockData";
import { EXPIRY_PRESETS, createGrant, readGrant } from "../chain/grants";
import type { TxState } from "../chain/transactions";
import { GRANT_STATUS_LABEL, PURPOSE_LABEL, Purpose, type AccessGrant, type Address, type Bytes32, type GrantStatus } from "../types/models";
import { formatEpoch, shortHex } from "./format";
import { TxProgress } from "./TxProgress";

const CUSTOM = "custom";

interface GrantFormProps {
  patient: Address;
  scopeCommitment: Bytes32;
  versionCount: number;
  /** Null when no verified wallet session exists (preview or signed out): the form cannot send. */
  canSign: boolean;
  onCancel: () => void;
  onCreated: () => void;
}

/** P3: review recipient, purpose and expiry, then confirm the grant in MetaMask. */
export function GrantForm({ patient, scopeCommitment, versionCount, canSign, onCancel, onCreated }: GrantFormProps) {
  const [recipientChoice, setRecipientChoice] = useState<string>(ANVIL_ACCOUNTS.clinician);
  const [customRecipient, setCustomRecipient] = useState("");
  const [expiryId, setExpiryId] = useState(EXPIRY_PRESETS[0].id);
  const [tx, setTx] = useState<TxState>({ phase: "idle" });
  const [created, setCreated] = useState<{ grant: AccessGrant; status: GrantStatus } | null>(null);

  const recipientRaw = recipientChoice === CUSTOM ? customRecipient.trim() : recipientChoice;
  const recipientValid = isAddress(recipientRaw);
  const recipient = recipientValid ? (getAddress(recipientRaw) as Address) : null;
  const isSelf = recipient !== null && recipient.toLowerCase() === patient.toLowerCase();
  const recipientError =
    recipientRaw === "" || recipientValid
      ? isSelf
        ? "You cannot grant access to yourself."
        : null
      : "Enter a valid wallet address (0x…).";

  const preset = EXPIRY_PRESETS.find((p) => p.id === expiryId) ?? EXPIRY_PRESETS[0];
  const busy = tx.phase === "awaiting-signature" || tx.phase === "pending";
  const canSubmit = canSign && recipient !== null && !isSelf && !busy && !created;

  async function submit() {
    if (!recipient) return;
    const result = await createGrant(
      {
        patient,
        grantee: recipient,
        purpose: Purpose.Treatment,
        scopeCommitment,
        durationSeconds: preset.seconds,
      },
      setTx,
    );
    // Show the grant as active only once the transaction is confirmed on chain.
    if (result.tx.phase === "confirmed") {
      try {
        const read = await readGrant(result.grantId);
        setCreated({ grant: read.grant, status: read.status });
        onCreated();
      } catch {
        setTx({
          phase: "failed",
          label: "Create grant",
          message: "The grant was confirmed, but it could not be read back from the chain. Refresh and check again.",
        });
      }
    }
  }

  if (created) {
    return (
      <section className="grant-form panel" aria-labelledby="grant-done-heading">
        <h3 id="grant-done-heading">Grant created</h3>
        <dl className="kv small">
          <dt>Status</dt>
          <dd>
            <span className={`badge badge-${GRANT_STATUS_LABEL[created.status].toLowerCase()}`}>
              {GRANT_STATUS_LABEL[created.status]}
            </span>
          </dd>
          <dt>Grant ID</dt>
          <dd className="mono" title={created.grant.grantId}>{shortHex(created.grant.grantId, 10, 8)}</dd>
          <dt>Recipient</dt>
          <dd className="mono" title={created.grant.grantee}>{shortHex(created.grant.grantee, 8, 6)}</dd>
          <dt>Purpose</dt>
          <dd>{PURPOSE_LABEL[created.grant.purpose]}</dd>
          <dt>Expires</dt>
          <dd>{formatEpoch(created.grant.expiresAt)} (chain time)</dd>
        </dl>
        <p className="small muted">
          Revoking stops future gateway releases only. It cannot recall data a recipient already received.
        </p>
        <TxProgress state={tx} />
      </section>
    );
  }

  return (
    <section className="grant-form panel" aria-labelledby="grant-form-heading">
      <h3 id="grant-form-heading">Share with a clinician</h3>

      <div className="field">
        <label htmlFor="grant-recipient">Recipient</label>
        <select
          id="grant-recipient"
          value={recipientChoice}
          disabled={busy}
          onChange={(e) => setRecipientChoice(e.target.value)}
        >
          <option value={ANVIL_ACCOUNTS.clinician}>Clinician · {shortHex(ANVIL_ACCOUNTS.clinician, 6, 4)} (Anvil #3)</option>
          <option value={CUSTOM}>Other wallet address…</option>
        </select>
        {recipientChoice === CUSTOM && (
          <input
            type="text"
            className="mono"
            placeholder="0x…"
            aria-label="Recipient wallet address"
            aria-invalid={recipientError !== null}
            value={customRecipient}
            disabled={busy}
            onChange={(e) => setCustomRecipient(e.target.value)}
          />
        )}
        {recipientError && <p className="small error-text" role="alert">{recipientError}</p>}
      </div>

      <div className="field">
        <span className="field-label">Purpose</span>
        <p className="small">{PURPOSE_LABEL[Purpose.Treatment]} <span className="muted">(research sharing needs its own approval screen)</span></p>
      </div>

      <fieldset className="field" disabled={busy}>
        <legend className="field-label">Expiry</legend>
        <div className="segmented" role="group" aria-label="Expiry">
          {EXPIRY_PRESETS.map((p) => (
            <button
              key={p.id}
              type="button"
              aria-pressed={expiryId === p.id}
              className={expiryId === p.id ? "is-on" : ""}
              onClick={() => setExpiryId(p.id)}
            >
              {p.label}
            </button>
          ))}
        </div>
        <p className="small muted">Counted from the latest chain time when you confirm.</p>
      </fieldset>

      <dl className="kv small">
        <dt>Versions</dt>
        <dd>{versionCount} selected</dd>
        <dt>Scope commitment</dt>
        <dd className="mono" title={scopeCommitment}>{shortHex(scopeCommitment, 10, 8)}</dd>
      </dl>

      <p className="small muted">
        What happens: MetaMask asks you to sign <span className="mono">grantAccess</span>. Only this recipient,
        purpose and version list are allowed until the expiry. You can revoke earlier.
      </p>

      {!canSign && (
        <p className="small error-text" role="status">
          Sign in with the patient wallet (Anvil account #2) to create a grant. The preview cannot send transactions.
        </p>
      )}

      <TxProgress state={tx} />

      <div className="row">
        <button type="button" className="btn btn-outline btn-sm" onClick={onCancel} disabled={busy}>
          Cancel
        </button>
        <button type="button" className="btn btn-sm" onClick={() => void submit()} disabled={!canSubmit}>
          {busy ? "Working…" : "Confirm in MetaMask"}
        </button>
      </div>
    </section>
  );
}

