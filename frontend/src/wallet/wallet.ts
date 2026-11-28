/**
 * MetaMask connection and wallet-challenge sign-in (ethers v6).
 *
 * The spec requires "a short-lived wallet-signature challenge bound to the session and chain".
 * The gateway does not exist yet, so `mockChallengeService` issues and checks the challenge in
 * the browser. That proves the signing flow works, but it is NOT a security check: the real
 * verification must happen on the gateway. The wallet never shares a private key with the app.
 */
import {
  BrowserProvider,
  getAddress,
  isError,
  toQuantity,
  verifyMessage,
  type Eip1193Provider,
} from "ethers";
import { ANVIL_ACCOUNTS } from "../mocks/mockData";
import type { Address } from "../types/models";

// ---------------------------------------------------------------------------
// Injected provider
// ---------------------------------------------------------------------------

export interface InjectedProvider extends Eip1193Provider {
  isMetaMask?: boolean;
  on?(event: string, handler: (...args: unknown[]) => void): void;
  removeListener?(event: string, handler: (...args: unknown[]) => void): void;
}

declare global {
  interface Window {
    ethereum?: InjectedProvider;
  }
}

export function getInjectedProvider(): InjectedProvider | null {
  return typeof window !== "undefined" && window.ethereum ? window.ethereum : null;
}

function requireProvider(): InjectedProvider {
  const eth = getInjectedProvider();
  if (!eth) throw new WalletError("MetaMask was not detected in this browser.");
  return eth;
}

// ---------------------------------------------------------------------------
// Network
// ---------------------------------------------------------------------------

// `||` so that an empty value in .env.local falls back to the default instead of chain 0.
export const EXPECTED_CHAIN_ID = BigInt(import.meta.env.VITE_CHAIN_ID || "31337");
export const RPC_URL: string = import.meta.env.VITE_RPC_URL || "http://127.0.0.1:8545";
export const NETWORK_NAME = EXPECTED_CHAIN_ID === 31337n ? "Anvil (local)" : `Chain ${EXPECTED_CHAIN_ID}`;

export function isExpectedChain(chainId: bigint | null): boolean {
  return chainId === EXPECTED_CHAIN_ID;
}

export interface WalletState {
  address: Address | null;
  chainId: bigint | null;
}

/** Reads the current account and chain without opening a MetaMask prompt. */
export async function readWalletState(): Promise<WalletState> {
  const eth = getInjectedProvider();
  if (!eth) return { address: null, chainId: null };
  const accounts = (await eth.request({ method: "eth_accounts" })) as string[];
  const chainHex = (await eth.request({ method: "eth_chainId" })) as string;
  return {
    address: accounts[0] ? (getAddress(accounts[0]) as Address) : null,
    chainId: BigInt(chainHex),
  };
}

/** Opens the MetaMask connection prompt. */
export async function connectWallet(): Promise<WalletState> {
  const eth = requireProvider();
  const accounts = (await eth.request({ method: "eth_requestAccounts" })) as string[];
  if (!accounts[0]) throw new WalletError("No account was shared by MetaMask.");
  const chainHex = (await eth.request({ method: "eth_chainId" })) as string;
  return { address: getAddress(accounts[0]) as Address, chainId: BigInt(chainHex) };
}

/** Asks MetaMask to switch to the expected chain, adding the local Anvil network if needed. */
export async function switchToExpectedChain(): Promise<void> {
  const eth = requireProvider();
  const chainId = toQuantity(EXPECTED_CHAIN_ID);
  try {
    await eth.request({ method: "wallet_switchEthereumChain", params: [{ chainId }] });
  } catch (e) {
    if (rpcErrorCode(e) !== 4902) throw e;
    await eth.request({
      method: "wallet_addEthereumChain",
      params: [
        {
          chainId,
          chainName: NETWORK_NAME,
          rpcUrls: [RPC_URL],
          nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
        },
      ],
    });
  }
}

/** ethers provider over MetaMask's connection (reads and signing use the wallet's chain). */
export function getBrowserProvider(): BrowserProvider {
  return new BrowserProvider(requireProvider());
}

/**
 * Asks MetaMask to drop this site's account permission (supported by current MetaMask versions).
 * If the wallet does not support it, the caller still forgets the account locally.
 */
export async function disconnectWallet(): Promise<void> {
  const eth = getInjectedProvider();
  if (!eth) return;
  try {
    await eth.request({ method: "wallet_revokePermissions", params: [{ eth_accounts: {} }] });
  } catch {
    // Older wallets: nothing to revoke remotely.
  }
}

// ---------------------------------------------------------------------------
// Roles (development mapping only)
// ---------------------------------------------------------------------------

export type Role = "patient" | "clinician" | "researcher" | "gateway" | "admin" | "unknown";

export const ROLE_LABEL: Record<Role, string> = {
  patient: "Patient",
  clinician: "Clinician",
  researcher: "Researcher",
  gateway: "Gateway signer",
  admin: "Contract admin",
  unknown: "Unknown role",
};

/**
 * Role hint from the Anvil account convention (docs/contract-interface.md §6).
 * Real roles will come from the gateway after sign-in; this is display only.
 */
export function devRoleFor(address: string | null): Role {
  if (!address) return "unknown";
  const a = address.toLowerCase();
  for (const [role, acct] of Object.entries(ANVIL_ACCOUNTS)) {
    if (acct.toLowerCase() === a) return role as Role;
  }
  return "unknown";
}

// ---------------------------------------------------------------------------
// Wallet challenge
// ---------------------------------------------------------------------------

export const CHALLENGE_TTL_SECONDS = 5 * 60;
export const SESSION_TTL_SECONDS = 30 * 60;

export interface WalletChallenge {
  message: string;
  address: Address;
  chainId: bigint;
  domain: string;
  nonce: string;
  issuedAt: Date;
  expiresAt: Date;
}

export interface WalletSession {
  address: Address;
  chainId: bigint;
  role: Role;
  signedInAt: Date;
  expiresAt: Date;
  /** "mock" = checked in the browser only; "gateway" = verified by the backend. */
  verifiedBy: "mock" | "gateway";
}

export interface ChallengeService {
  requestChallenge(address: Address, chainId: bigint): Promise<WalletChallenge>;
  verify(challenge: WalletChallenge, signature: string): Promise<WalletSession>;
}

/** EIP-4361 (Sign-In with Ethereum) style message, bound to domain, account, chain, nonce and expiry. */
export function buildChallengeMessage(c: Omit<WalletChallenge, "message">): string {
  return [
    `${c.domain} wants you to sign in with your Ethereum account:`,
    c.address,
    "",
    "Sign in to CareConsent. This signature only proves that you control this wallet. " +
      "It does not send a transaction, grant access or share any health data.",
    "",
    `URI: ${window.location.origin}`,
    "Version: 1",
    `Chain ID: ${c.chainId.toString()}`,
    `Nonce: ${c.nonce}`,
    `Issued At: ${c.issuedAt.toISOString()}`,
    `Expiration Time: ${c.expiresAt.toISOString()}`,
  ].join("\n");
}

function randomNonce(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/** Browser-side stand-in for the gateway's challenge endpoints. Nonces are single-use. */
export function createMockChallengeService(): ChallengeService {
  const issued = new Map<string, WalletChallenge>();
  return {
    async requestChallenge(address, chainId) {
      const issuedAt = new Date();
      const base = {
        address,
        chainId,
        domain: window.location.host,
        nonce: randomNonce(),
        issuedAt,
        expiresAt: new Date(issuedAt.getTime() + CHALLENGE_TTL_SECONDS * 1000),
      };
      const challenge = { ...base, message: buildChallengeMessage(base) };
      issued.set(challenge.nonce, challenge);
      return challenge;
    },
    async verify(challenge, signature) {
      const known = issued.get(challenge.nonce);
      issued.delete(challenge.nonce); // single use, even when verification fails
      if (!known || known.message !== challenge.message) {
        throw new WalletError("Sign-in challenge is unknown or was already used. Please try again.");
      }
      if (Date.now() >= known.expiresAt.getTime()) {
        throw new WalletError("Sign-in challenge expired. Please try again.");
      }
      if (known.domain !== window.location.host) {
        throw new WalletError("Sign-in challenge was issued for a different site.");
      }
      const current = await readWalletState();
      if (current.chainId !== known.chainId || !isExpectedChain(current.chainId)) {
        throw new WalletError("The network changed during sign-in. Please try again.");
      }
      if (current.address?.toLowerCase() !== known.address.toLowerCase()) {
        throw new WalletError("The MetaMask account changed during sign-in. Please try again.");
      }
      const recovered = verifyMessage(known.message, signature);
      if (recovered.toLowerCase() !== known.address.toLowerCase()) {
        throw new WalletError("The signature does not match the connected account.");
      }
      const signedInAt = new Date();
      return {
        address: known.address,
        chainId: known.chainId,
        role: devRoleFor(known.address),
        signedInAt,
        expiresAt: new Date(signedInAt.getTime() + SESSION_TTL_SECONDS * 1000),
        verifiedBy: "mock",
      };
    },
  };
}

/** Placeholder until the gateway auth endpoints are agreed; fails closed. */
export const gatewayChallengeService: ChallengeService = {
  async requestChallenge() {
    throw new WalletError("Gateway sign-in is not connected yet (VITE_USE_MOCK=false).");
  },
  async verify() {
    throw new WalletError("Gateway sign-in is not connected yet (VITE_USE_MOCK=false).");
  },
};

/** Full sign-in: request challenge → MetaMask personal_sign → verify. */
export async function signInWithWallet(
  service: ChallengeService,
  address: Address,
  chainId: bigint,
): Promise<WalletSession> {
  if (!isExpectedChain(chainId)) {
    throw new WalletError(`Switch MetaMask to ${NETWORK_NAME} (chain ${EXPECTED_CHAIN_ID}) before signing in.`);
  }
  const signer = await getBrowserProvider().getSigner(address);
  const challenge = await service.requestChallenge(address, chainId);
  const signature = await signer.signMessage(challenge.message);
  return service.verify(challenge, signature);
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

export class WalletError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "WalletError";
  }
}

function rpcErrorCode(e: unknown): number | undefined {
  if (typeof e !== "object" || e === null) return undefined;
  const direct = (e as { code?: unknown }).code;
  if (typeof direct === "number") return direct;
  const nested = (e as { error?: { code?: unknown } }).error?.code;
  return typeof nested === "number" ? nested : undefined;
}

/** User-facing text for wallet errors. */
export function describeWalletError(e: unknown): string {
  if (e instanceof WalletError) return e.message;
  if (isError(e, "ACTION_REJECTED") || rpcErrorCode(e) === 4001) {
    return "The request was rejected in MetaMask.";
  }
  if (rpcErrorCode(e) === -32002) {
    return "A MetaMask request is already open. Open MetaMask to continue.";
  }
  return "MetaMask could not complete the request. Check MetaMask and try again.";
}
