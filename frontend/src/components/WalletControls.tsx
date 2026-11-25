import type { UseWallet } from "../wallet/useWallet";
import { EXPECTED_CHAIN_ID, NETWORK_NAME, ROLE_LABEL } from "../wallet/wallet";
import { shortHex } from "./format";

/** Top-bar wallet area: connect button, address and role badge, sign-in state. */
export function WalletControls({ wallet }: { wallet: UseWallet }) {
  const { hasProvider, address, onExpectedChain, role, session, busy } = wallet;

  if (!hasProvider) {
    return (
      <div className="wallet">
        <span className="muted small">MetaMask not detected</span>
        <a className="btn btn-outline btn-sm" href="https://metamask.io/download/" target="_blank" rel="noreferrer">
          Install MetaMask
        </a>
      </div>
    );
  }

  if (!address) {
    return (
      <div className="wallet">
        <button type="button" className="btn" onClick={() => void wallet.connect()} disabled={busy !== null}>
          {busy === "connecting" ? "Connecting…" : "Connect wallet"}
        </button>
      </div>
    );
  }

  return (
    <div className="wallet">
      <span className="address-badge" title={address}>
        <span className={`dot ${onExpectedChain ? "dot-ok" : "dot-warn"}`} aria-hidden="true" />
        <span className="mono">{shortHex(address)}</span>
        <span className="role" title="Role from the Anvil test-account convention (display only)">
          {ROLE_LABEL[role]}
        </span>
      </span>

      {session ? (
        <>
          <span className="badge badge-active" title={`Session ends ${session.expiresAt.toLocaleTimeString()}`}>
            Signed in{session.verifiedBy === "mock" ? " · mock check" : ""}
          </span>
          <button type="button" className="btn btn-outline btn-sm" onClick={wallet.signOut}>
            Sign out
          </button>
        </>
      ) : (
        <button
          type="button"
          className="btn btn-sm"
          onClick={() => void wallet.signIn()}
          disabled={busy !== null || !onExpectedChain}
          title={onExpectedChain ? "Sign a one-time message to prove wallet ownership" : `Switch to ${NETWORK_NAME} first`}
        >
          {busy === "signing" ? "Waiting for signature…" : "Sign in"}
        </button>
      )}
    </div>
  );
}

/** Warning bar when MetaMask is on another chain, plus wallet errors. */
export function WalletNotices({ wallet }: { wallet: UseWallet }) {
  const { address, chainId, onExpectedChain, busy, error } = wallet;
  return (
    <>
      {address && !onExpectedChain && (
        <div className="banner banner-warn" role="alert">
          <span>
            Wrong network: MetaMask is on chain {chainId?.toString() ?? "unknown"}. CareConsent uses{" "}
            {NETWORK_NAME} (chain {EXPECTED_CHAIN_ID.toString()}). Signing in is disabled until you switch.
          </span>
          <button
            type="button"
            className="btn btn-sm"
            onClick={() => void wallet.switchNetwork()}
            disabled={busy !== null}
          >
            {busy === "switching" ? "Switching…" : `Switch to ${NETWORK_NAME}`}
          </button>
        </div>
      )}
      {error && (
        <div className="banner banner-error" role="alert">
          <span>{error}</span>
          <button type="button" className="link-btn" onClick={wallet.clearError}>
            Dismiss
          </button>
        </div>
      )}
    </>
  );
}
