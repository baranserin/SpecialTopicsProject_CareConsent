/**
 * Shared MetaMask transaction flow: review → confirm in MetaMask → wait for confirmation →
 * confirmed | rejected | reverted. The UI must only show a new on-chain state after `confirmed`
 * (docs/design/frontend-screen-flow.md §3.3).
 */
import { isError, type ContractTransactionResponse } from "ethers";
import { CONTRACT_INTERFACES, CONTRACT_NAMES } from "./contracts";

export type TxState =
  | { phase: "idle" }
  | { phase: "awaiting-signature"; label: string }
  | { phase: "pending"; label: string; hash: string }
  | { phase: "confirmed"; label: string; hash: string; blockNumber: number }
  | { phase: "rejected"; label: string; message: string }
  | { phase: "reverted"; label: string; message: string; errorName?: string; hash?: string }
  | { phase: "failed"; label: string; message: string };

/** Plain-language text for the custom errors a frontend-signed transaction can hit. */
const ERROR_TEXT: Record<string, string> = {
  // RecordRegistry
  InvalidVersionId: "The record version identifier is missing.",
  InvalidCiphertextDigest: "The encrypted record digest is missing.",
  VersionAlreadyRegistered: "This record version is already registered.",
  ReplacedVersionNotFound: "The version being corrected is not registered under your account.",
  VersionNotFound: "This record version is not registered.",
  NotVersionOwner: "Only the record owner can do this.",
  VersionAlreadyRetired: "This record version is already retired.",
  // ConsentManager
  InvalidGrantId: "The grant identifier is missing.",
  GrantAlreadyExists: "A grant with this identifier already exists.",
  InvalidGrantee: "Choose a valid recipient other than yourself.",
  InvalidPurpose: "Choose a purpose for this grant.",
  InvalidScopeCommitment: "Select at least one record version to share.",
  ExpiryNotInFuture: "Choose an expiry time in the future.",
  GrantNotFound: "This grant does not exist.",
  NotGrantOwner: "Only the patient who created this grant can change it.",
  GrantAlreadyRevoked: "This grant has already been revoked.",
  GrantAlreadyExpired: "This grant has already expired; there is nothing to revoke.",
  // ResearchSettlement
  InvalidRequestId: "The research request identifier is missing.",
  RequestAlreadyExists: "A research request with this identifier already exists.",
  InvalidPatient: "Choose a valid patient other than yourself.",
  InvalidFee: "Enter a fee greater than zero.",
  InsufficientTestCredits: "Your test-credit balance is too low for this fee.",
  RequestNotFound: "This research request does not exist.",
  NotRequestPatient: "Only the named patient can refuse this request.",
  RequestAlreadyRefused: "This research request was already refused.",
  RequestAlreadySettled: "This research request was already settled.",
  RequestAlreadyRefunded: "This research request was already refunded.",
  RequestIsExpired: "This research request has expired.",
  RequestNotExpired: "This request has not expired yet, so it cannot be refunded.",
};

export interface DecodedContractError {
  name: string;
  message: string;
}

function findRevertData(e: unknown): string | null {
  const seen = new Set<unknown>();
  const stack: unknown[] = [e];
  while (stack.length) {
    const cur = stack.pop();
    if (!cur || typeof cur !== "object" || seen.has(cur)) continue;
    seen.add(cur);
    const data = (cur as { data?: unknown }).data;
    if (typeof data === "string" && /^0x[0-9a-fA-F]{8}/.test(data)) return data;
    for (const key of ["error", "info", "data", "cause"]) stack.push((cur as Record<string, unknown>)[key]);
  }
  return null;
}

/** Finds the contract's custom error in an ethers/MetaMask error, using all three ABIs. */
export function decodeContractError(e: unknown): DecodedContractError | null {
  let name: string | undefined;
  const revert = (e as { revert?: { name?: string } } | null)?.revert;
  if (revert?.name) name = revert.name;
  if (!name) {
    const data = findRevertData(e);
    if (data) {
      for (const c of CONTRACT_NAMES) {
        try {
          const parsed = CONTRACT_INTERFACES[c].parseError(data);
          if (parsed) {
            name = parsed.name;
            break;
          }
        } catch {
          // not this contract's error
        }
      }
    }
  }
  if (!name) return null;
  return {
    name,
    message: ERROR_TEXT[name] ?? `The contract refused the transaction (${name}).`,
  };
}

function isUserRejection(e: unknown): boolean {
  if (isError(e, "ACTION_REJECTED")) return true;
  const code = (e as { code?: unknown; error?: { code?: unknown } } | null);
  return code?.code === 4001 || code?.error?.code === 4001;
}

/**
 * Runs one contract transaction and reports each phase through `onState`.
 * Resolves with the final state; never throws.
 */
export async function runTransaction(
  label: string,
  send: () => Promise<ContractTransactionResponse>,
  onState: (s: TxState) => void,
): Promise<TxState> {
  const finish = (s: TxState) => {
    onState(s);
    return s;
  };
  onState({ phase: "awaiting-signature", label });
  let tx: ContractTransactionResponse;
  try {
    tx = await send();
  } catch (e) {
    if (isUserRejection(e)) return finish({ phase: "rejected", label, message: "You rejected the request in MetaMask." });
    const decoded = decodeContractError(e);
    if (decoded) return finish({ phase: "reverted", label, message: decoded.message, errorName: decoded.name });
    return finish({ phase: "failed", label, message: "The transaction could not be sent. Check MetaMask and the local chain." });
  }
  onState({ phase: "pending", label, hash: tx.hash });
  try {
    const receipt = await tx.wait();
    if (!receipt || receipt.status !== 1) {
      return finish({ phase: "reverted", label, hash: tx.hash, message: "The transaction was reverted by the contract." });
    }
    return finish({ phase: "confirmed", label, hash: tx.hash, blockNumber: receipt.blockNumber });
  } catch (e) {
    const decoded = decodeContractError(e);
    return finish({
      phase: "reverted",
      label,
      hash: tx.hash,
      message: decoded?.message ?? "The transaction was reverted by the contract.",
      errorName: decoded?.name,
    });
  }
}
