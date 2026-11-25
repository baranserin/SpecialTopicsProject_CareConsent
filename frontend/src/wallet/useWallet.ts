import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { getAddress } from "ethers";
import { USE_MOCK } from "../api/records";
import type { Address } from "../types/models";
import {
  connectWallet,
  createMockChallengeService,
  describeWalletError,
  devRoleFor,
  gatewayChallengeService,
  getInjectedProvider,
  isExpectedChain,
  readWalletState,
  signInWithWallet,
  switchToExpectedChain,
  WalletError,
  type Role,
  type WalletSession,
} from "./wallet";

export type WalletBusy = "connecting" | "switching" | "signing" | null;

export interface UseWallet {
  hasProvider: boolean;
  address: Address | null;
  chainId: bigint | null;
  onExpectedChain: boolean;
  role: Role;
  session: WalletSession | null;
  busy: WalletBusy;
  error: string | null;
  connect: () => Promise<void>;
  switchNetwork: () => Promise<void>;
  signIn: () => Promise<void>;
  signOut: () => void;
  clearError: () => void;
}

export function useWallet(): UseWallet {
  const hasProvider = getInjectedProvider() !== null;
  const [address, setAddress] = useState<Address | null>(null);
  const [chainId, setChainId] = useState<bigint | null>(null);
  const [session, setSession] = useState<WalletSession | null>(null);
  const [busy, setBusy] = useState<WalletBusy>(null);
  const [error, setError] = useState<string | null>(null);
  const service = useRef(USE_MOCK ? createMockChallengeService() : gatewayChallengeService);
  // Latest account/chain, so a sign-in that finishes after a MetaMask change is discarded.
  const latest = useRef<{ address: Address | null; chainId: bigint | null }>({ address: null, chainId: null });
  latest.current = { address, chainId };

  // Restore an existing connection (no prompt) and follow MetaMask account/chain changes.
  // A session is bound to one account and chain, so any change ends it.
  useEffect(() => {
    const eth = getInjectedProvider();
    if (!eth) return;
    readWalletState()
      .then((s) => {
        setAddress(s.address);
        setChainId(s.chainId);
      })
      .catch(() => undefined);

    const onAccounts = (...args: unknown[]) => {
      const accounts = (args[0] as string[] | undefined) ?? [];
      setAddress(accounts[0] ? (getAddress(accounts[0]) as Address) : null);
      setSession(null);
    };
    const onChain = (...args: unknown[]) => {
      setChainId(BigInt(args[0] as string));
      setSession(null);
    };
    eth.on?.("accountsChanged", onAccounts);
    eth.on?.("chainChanged", onChain);
    return () => {
      eth.removeListener?.("accountsChanged", onAccounts);
      eth.removeListener?.("chainChanged", onChain);
    };
  }, []);

  // End the session when it expires.
  useEffect(() => {
    if (!session) return;
    const ms = session.expiresAt.getTime() - Date.now();
    const t = window.setTimeout(() => setSession(null), Math.max(0, ms));
    return () => window.clearTimeout(t);
  }, [session]);

  const run = useCallback(async (kind: Exclude<WalletBusy, null>, fn: () => Promise<void>) => {
    setBusy(kind);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(describeWalletError(e));
    } finally {
      setBusy(null);
    }
  }, []);

  const connect = useCallback(
    () =>
      run("connecting", async () => {
        const s = await connectWallet();
        setAddress(s.address);
        setChainId(s.chainId);
      }),
    [run],
  );

  const switchNetwork = useCallback(
    () =>
      run("switching", async () => {
        await switchToExpectedChain();
        const s = await readWalletState();
        setChainId(s.chainId);
      }),
    [run],
  );

  const signIn = useCallback(
    () =>
      run("signing", async () => {
        if (!address || chainId === null) throw new WalletError("Connect MetaMask before signing in.");
        const result = await signInWithWallet(service.current, address, chainId);
        const now = latest.current;
        if (now.address?.toLowerCase() !== result.address.toLowerCase() || now.chainId !== result.chainId) {
          throw new WalletError("The MetaMask account or network changed during sign-in. Please try again.");
        }
        setSession(result);
      }),
    [run, address, chainId],
  );

  const signOut = useCallback(() => setSession(null), []);
  const clearError = useCallback(() => setError(null), []);

  const role = useMemo(() => devRoleFor(address), [address]);

  return {
    hasProvider,
    address,
    chainId,
    onExpectedChain: isExpectedChain(chainId),
    role,
    session,
    busy,
    error,
    connect,
    switchNetwork,
    signIn,
    signOut,
    clearError,
  };
}
