import { useEffect, useState } from "react";
import { USE_MOCK } from "./api/records";
import { MOCK_PATIENT } from "./mocks/mockData";
import { AccessDenied } from "./components/StatusMessage";
import { ChainStatusPanel } from "./components/ChainStatusPanel";
import { WalletControls, WalletNotices } from "./components/WalletControls";
import { PatientRecords } from "./pages/PatientRecords";
import { GrantList } from "./components/GrantList";
import { useWallet } from "./wallet/useWallet";
import { ROLE_LABEL } from "./wallet/wallet";

/**
 * Who may see the patient records page:
 * - "owner": signed in with the wallet that owns the records
 * - "preview": not signed in, synthetic preview explicitly opened (mock mode only)
 * - "other": signed in with another account (clinician, researcher, ...)
 * - "signed-out": not signed in
 */
type Access = "owner" | "preview" | "other" | "signed-out";

type View = "records" | "grants";
const VIEWS: { id: View; label: string }[] = [
  { id: "records", label: "Records" },
  { id: "grants", label: "My grants" },
];

export default function App() {
  const wallet = useWallet();
  const [preview, setPreview] = useState(false);
  const [view, setView] = useState<View>("records");
  // Bumped when a grant is created, so the grants tab reloads.
  const [grantsVersion, setGrantsVersion] = useState(0);

  const session = wallet.session;
  const access: Access = session
    ? session.address.toLowerCase() === MOCK_PATIENT.address.toLowerCase()
      ? "owner"
      : "other"
    : preview && USE_MOCK
      ? "preview"
      : "signed-out";

  // Signing in replaces the anonymous preview.
  useEffect(() => {
    if (session) setPreview(false);
  }, [session]);

  return (
    <div className="app">
      <header className="topbar">
        <div className="brand">
          Care<span className="logo">Consent</span>
        </div>
        <div className="topbar-right">
          {USE_MOCK && <span className="badge badge-warn">Synthetic demo data</span>}
          <WalletControls wallet={wallet} />
        </div>
      </header>
      <WalletNotices wallet={wallet} />

      <main className="content">
        <div className="page-head">
          <div>
            <h1>My health records</h1>
            <p className="muted">
              {access === "owner" || access === "preview"
                ? `${MOCK_PATIENT.label} · records you own and the versions you can choose to share.`
                : "Sign in with your patient wallet to see your own records."}
            </p>
          </div>
        </div>

        <ChainStatusPanel wallet={wallet} />

        {access === "preview" && (
          <div className="banner banner-warn inline-banner" role="status">
            <span>Preview without sign-in: synthetic data only. Sign in as the patient (Anvil account #2) for the real flow.</span>
            <button type="button" className="link-btn" onClick={() => setPreview(false)}>
              Close preview
            </button>
          </div>
        )}

        {access === "owner" && (
          <nav className="segmented demo-switch" aria-label="Patient pages">
            {VIEWS.map((v) => (
              <button
                key={v.id}
                type="button"
                aria-pressed={view === v.id}
                className={view === v.id ? "is-on" : ""}
                onClick={() => setView(v.id)}
              >
                {v.label}
              </button>
            ))}
          </nav>
        )}

        {access === "owner" && view === "grants" && wallet.onExpectedChain && (
          <GrantList patient={MOCK_PATIENT.address} refreshKey={grantsVersion} />
        )}
        {access === "owner" && view === "grants" && !wallet.onExpectedChain && (
          <AccessDenied title="Wrong network" detail="Switch MetaMask to the local Anvil network to see your grants." />
        )}

        {((access === "owner" && view === "records") || access === "preview") && <PatientRecords
            patientAddress={MOCK_PATIENT.address}
            canSign={access === "owner" && wallet.onExpectedChain}
            onGrantCreated={() => setGrantsVersion((v) => v + 1)}
          />}

        {access === "other" && session && (
          <AccessDenied
            detail={`You are signed in as ${ROLE_LABEL[session.role]}. This page shows a patient's own records only. Switch MetaMask to the patient account to continue.`}
          />
        )}

        {access === "signed-out" && (
          <section className="panel signin-card">
            <h2>Sign in to see your records</h2>
            <ol className="small">
              <li>Connect MetaMask (top right).</li>
              <li>Switch to the local Anvil network if asked.</li>
              <li>Click <strong>Sign in</strong> and sign the one-time message. It sends no transaction.</li>
            </ol>
            {USE_MOCK && (
              <button type="button" className="btn btn-outline btn-sm" onClick={() => setPreview(true)}>
                Preview with synthetic data (no wallet)
              </button>
            )}
          </section>
        )}
      </main>
    </div>
  );
}
