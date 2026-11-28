import type { TxState } from "../chain/transactions";
import { shortHex } from "./format";

/** Shows the phase of a MetaMask transaction (design doc §3.3). Renders nothing while idle. */
export function TxProgress({ state }: { state: TxState }) {
  switch (state.phase) {
    case "idle":
      return null;
    case "awaiting-signature":
      return (
        <p className="banner banner-warn" role="status">
          Confirm “{state.label}” in MetaMask…
        </p>
      );
    case "pending":
      return (
        <p className="banner banner-warn" role="status">
          Waiting for confirmation… <span className="mono" title={state.hash}>{shortHex(state.hash, 10, 8)}</span>
        </p>
      );
    case "confirmed":
      return (
        <p className="banner banner-ok" role="status">
          Confirmed in block {state.blockNumber}. <span className="mono" title={state.hash}>{shortHex(state.hash, 10, 8)}</span>
        </p>
      );
    case "rejected":
      return (
        <p className="banner banner-warn" role="alert">
          {state.message}
        </p>
      );
    case "reverted":
    case "failed":
      return (
        <p className="banner banner-error" role="alert">
          {state.message}
        </p>
      );
  }
}
