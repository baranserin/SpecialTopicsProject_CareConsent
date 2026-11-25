/**
 * Read-only checks that the connected wallet can actually reach the CareConsent contracts.
 * Uses MetaMask's own RPC connection, so it reflects the chain the wallet will sign on.
 */
import type { Provider } from "ethers";
import { CONTRACT_ADDRESSES, CONTRACT_NAMES, getContract, type ContractName } from "./contracts";
import type { Address, UnixSeconds } from "../types/models";

export interface ChainStatus {
  blockNumber: number;
  /** Latest block timestamp. Expiry decisions use this, never the browser clock. */
  chainTime: UnixSeconds;
  deployed: Record<ContractName, boolean>;
  allDeployed: boolean;
  ethBalanceWei: bigint;
  /** ResearchSettlement.creditBalances(account); null when the contract is not deployed. */
  testCredits: bigint | null;
}

export async function readChainStatus(provider: Provider, account: Address): Promise<ChainStatus> {
  const block = await provider.getBlock("latest");
  if (!block) throw new Error("No block returned by the chain.");

  const codes = await Promise.all(CONTRACT_NAMES.map((n) => provider.getCode(CONTRACT_ADDRESSES[n])));
  const deployed = Object.fromEntries(
    CONTRACT_NAMES.map((n, i) => [n, codes[i] !== "0x"]),
  ) as Record<ContractName, boolean>;
  const allDeployed = CONTRACT_NAMES.every((n) => deployed[n]);

  const [ethBalanceWei, testCredits] = await Promise.all([
    provider.getBalance(account),
    deployed.ResearchSettlement
      ? (getContract("ResearchSettlement", provider).getFunction("creditBalances")(account) as Promise<bigint>).catch(
          () => null,
        )
      : Promise.resolve(null),
  ]);

  return { blockNumber: block.number, chainTime: block.timestamp, deployed, allDeployed, ethBalanceWei, testCredits };
}
