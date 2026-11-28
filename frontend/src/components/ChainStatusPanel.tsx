import { useCallback, useEffect, useRef, useState } from "react";
import { formatEther } from "ethers";
import { readChainStatus, type ChainStatus } from "../chain/chainStatus";
import { CONTRACT_ADDRESSES, CONTRACT_NAMES } from "../chain/contracts";
import { getBrowserProvider, NETWORK_NAME } from "../wallet/wallet";
import type { UseWallet } from "../wallet/useWallet";
import { formatEpoch, shortHex } from "./format";

type Check =
  | { kind: "idle" }
  | { kind: "checking" }
  | { kind: "ok"; status: ChainStatus }
  | { kind: "unreachable" };

/**
 * Shows whether the connected wallet reaches the local chain and the deployed contracts.
 * Problems open the panel automatically, because transactions would fail without them.
 */
export function ChainStatusPanel({ wallet }: { wallet: UseWallet }) {
  const { address, chainId, onExpectedChain } = wallet;
  const [check, setCheck] = useState<Check>({ kind: "idle" });
  const seq = useRef(0);

  const refresh = useCallback(async () => {
    if (!address || !onExpectedChain) return;
    const mine = ++seq.current;
    setCheck({ kind: "checking" });
    try {
      const status = await readChainStatus(getBrowserProvider(), address);
      if (mine === seq.current) setCheck({ kind: "ok", status });
    } catch {
      if (mine === seq.current) setCheck({ kind: "unreachable" });
    }
  }, [address, onExpectedChain]);

  useEffect(() => {
    setCheck({ kind: "idle" });
    void refresh();
  }, [refresh, chainId]);

  if (!address || !onExpectedChain) return null;

  const problem =
    check.kind === "unreachable" || (check.kind === "ok" && !check.status.allDeployed);

  return (
    <details className="panel chain-panel" open={problem}>
      <summary>
        <span>Network &amp; contracts</span>
        {check.kind === "checking" && <span className="muted small">checking…</span>}
        {check.kind === "ok" && check.status.allDeployed && (
          <span className="badge badge-active">{NETWORK_NAME} · block {check.status.blockNumber}</span>
        )}
        {check.kind === "ok" && !check.status.allDeployed && (
          <span className="badge badge-retired">Contracts missing</span>
        )}
        {check.kind === "unreachable" && <span className="badge badge-retired">Chain not reachable</span>}
      </summary>

      {check.kind === "unreachable" && (
        <p className="small error-text" role="alert">
          MetaMask could not reach the local chain. Start it with <code>anvil</code> and click Refresh.
        </p>
      )}

      {check.kind === "ok" && (
        <>
          {!check.status.allDeployed && (
            <p className="small error-text" role="alert">
              Some contracts are not deployed at the configured addresses. Run{" "}
              <code>contracts/script/DeployCareConsent.s.sol</code> on a fresh Anvil, or set the
              addresses it prints in <code>frontend/.env.local</code>.
            </p>
          )}
          <dl className="kv">
            <div className="kv-row">
              <dt>Chain time</dt>
              <dd>
                {formatEpoch(check.status.chainTime)}{" "}
                <span className="muted small">(used for grant expiry, not the browser clock)</span>
              </dd>
            </div>
            <div className="kv-row">
              <dt>Your balance</dt>
              <dd>
                {Number(formatEther(check.status.ethBalanceWei)).toFixed(4)} ETH
                {check.status.testCredits !== null && <> · {check.status.testCredits.toString()} test credits</>}
              </dd>
            </div>
            {CONTRACT_NAMES.map((n) => (
              <div key={n} className="kv-row">
                <dt>{n}</dt>
                <dd>
                  <span className="mono" title={CONTRACT_ADDRESSES[n]}>{shortHex(CONTRACT_ADDRESSES[n])}</span>{" "}
                  {check.status.deployed[n] ? (
                    <span className="badge badge-active">deployed</span>
                  ) : (
                    <span className="badge badge-retired">no code</span>
                  )}
                </dd>
              </div>
            ))}
          </dl>
        </>
      )}

      <button type="button" className="btn btn-outline btn-sm" onClick={() => void refresh()} disabled={check.kind === "checking"}>
        Refresh
      </button>
    </details>
  );
}
