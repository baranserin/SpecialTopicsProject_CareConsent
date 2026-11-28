/**
 * Patient-side ConsentManager calls: create a grant (grantAccess) and read it back.
 * The UI shows a grant as active only after `runTransaction` reports `confirmed`
 * (docs/design/frontend-screen-flow.md §3.3, P3).
 */
import { hexlify, randomBytes, type EventLog } from "ethers";
import { getContract } from "./contracts";
import { runTransaction, type TxState } from "./transactions";
import { getBrowserProvider } from "../wallet/wallet";
import {
  type GrantStatus,
  type Purpose,
  type AccessGrant,
  type Address,
  type Bytes32,
  type UnixSeconds,
} from "../types/models";

export interface ExpiryPreset {
  id: string;
  label: string;
  seconds: number;
}

/** 30 days is the thirty-day clinician-access demo from the proposal. */
export const EXPIRY_PRESETS: ExpiryPreset[] = [
  { id: "30d", label: "30 days", seconds: 30 * 24 * 3600 },
  { id: "7d", label: "7 days", seconds: 7 * 24 * 3600 },
  { id: "1d", label: "1 day", seconds: 24 * 3600 },
];

/** Opaque, unique grant identifier (random bytes32; contains no patient data). */
export function newGrantId(): Bytes32 {
  return hexlify(randomBytes(32)) as Bytes32;
}

/** Latest block time. Expiry is always computed from chain time, never the browser clock. */
export async function readChainTime(): Promise<UnixSeconds> {
  const block = await getBrowserProvider().getBlock("latest");
  if (!block) throw new Error("No block returned by the chain.");
  return block.timestamp;
}

export interface CreateGrantInput {
  patient: Address;
  grantee: Address;
  purpose: Purpose;
  scopeCommitment: Bytes32;
  /** Seconds from the latest chain time until expiry. */
  durationSeconds: number;
}

export interface CreateGrantResult {
  grantId: Bytes32;
  expiresAt: UnixSeconds;
  tx: TxState;
}

/** Signs and sends ConsentManager.grantAccess through MetaMask, reporting every phase. */
export async function createGrant(
  input: CreateGrantInput,
  onState: (s: TxState) => void,
): Promise<CreateGrantResult> {
  const grantId = newGrantId();
  let expiresAt: UnixSeconds = 0;
  const tx = await runTransaction(
    "Create grant",
    async () => {
      const signer = await getBrowserProvider().getSigner(input.patient);
      const chainTime = await readChainTime();
      expiresAt = chainTime + input.durationSeconds;
      const consent = getContract("ConsentManager", signer);
      return consent.grantAccess(grantId, input.grantee, input.purpose, input.scopeCommitment, expiresAt);
    },
    onState,
  );
  return { grantId, expiresAt, tx };
}

/** Reads the grant back from the chain (used after confirmation). */
export async function readGrant(grantId: Bytes32): Promise<{ grant: AccessGrant; status: GrantStatus }> {
  const consent = getContract("ConsentManager", getBrowserProvider());
  const [g, status] = await Promise.all([consent.getGrant(grantId), consent.getGrantStatus(grantId)]);
  return {
    grant: {
      grantId,
      owner: g.owner,
      grantee: g.grantee,
      purpose: Number(g.purpose) as Purpose,
      scopeCommitment: g.scopeCommitment,
      grantedAt: Number(g.grantedAt),
      expiresAt: Number(g.expiresAt),
      revoked: g.revoked,
      revokedAt: Number(g.revokedAt),
    },
    status: Number(status) as GrantStatus,
  };
}


export interface GrantRow {
  grant: AccessGrant;
  status: GrantStatus;
}

/** All grants created by `owner`, newest first, with their current on-chain status. */
export async function listGrants(owner: Address): Promise<{ rows: GrantRow[]; chainTime: UnixSeconds }> {
  const consent = getContract("ConsentManager", getBrowserProvider());
  const events = await consent.queryFilter(consent.filters.GrantCreated(null, owner));
  const ids = events.map((e) => (e as EventLog).args[0] as Bytes32);
  const rows = await Promise.all(ids.map((id) => readGrant(id)));
  rows.sort((a, b) => b.grant.grantedAt - a.grant.grantedAt);
  return { rows, chainTime: await readChainTime() };
}

/** Signs and sends ConsentManager.revokeGrant. Revocation blocks future gateway releases only. */
export function revokeGrant(grantId: Bytes32, owner: Address, onState: (s: TxState) => void): Promise<TxState> {
  return runTransaction(
    "Revoke grant",
    async () => {
      const signer = await getBrowserProvider().getSigner(owner);
      return getContract("ConsentManager", signer).revokeGrant(grantId);
    },
    onState,
  );
}
