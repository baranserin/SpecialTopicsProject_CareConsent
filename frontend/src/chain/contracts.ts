/**
 * Contract addresses and ABIs.
 *
 * ABIs are imported directly from `contracts/abi/` (owned by the smart-contract module), so the
 * frontend never keeps its own copy that could drift from the deployed contracts.
 */
import { Contract, Interface, getAddress, type ContractRunner, type InterfaceAbi } from "ethers";
import recordRegistryAbi from "../../../contracts/abi/RecordRegistry.json";
import consentManagerAbi from "../../../contracts/abi/ConsentManager.json";
import researchSettlementAbi from "../../../contracts/abi/ResearchSettlement.json";
import type { Address } from "../types/models";

export type ContractName = "RecordRegistry" | "ConsentManager" | "ResearchSettlement";
export const CONTRACT_NAMES: ContractName[] = ["RecordRegistry", "ConsentManager", "ResearchSettlement"];

/**
 * Defaults = addresses produced by `contracts/script/DeployCareConsent.s.sol` when it is the first
 * thing run on a fresh Anvil (deployer account #0, nonces 0, 1, 2). Override them in `.env.local`
 * with the addresses printed by the deploy script if your chain differs.
 */
const DEFAULT_ADDRESSES: Record<ContractName, string> = {
  RecordRegistry: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  ConsentManager: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  ResearchSettlement: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
};

const ENV_ADDRESSES: Record<ContractName, string | undefined> = {
  RecordRegistry: import.meta.env.VITE_RECORD_REGISTRY_ADDRESS,
  ConsentManager: import.meta.env.VITE_CONSENT_MANAGER_ADDRESS,
  ResearchSettlement: import.meta.env.VITE_RESEARCH_SETTLEMENT_ADDRESS,
};

export const CONTRACT_ADDRESSES: Record<ContractName, Address> = Object.fromEntries(
  CONTRACT_NAMES.map((n) => [n, getAddress(ENV_ADDRESSES[n] || DEFAULT_ADDRESSES[n]) as Address]),
) as Record<ContractName, Address>;

export const CONTRACT_ABIS: Record<ContractName, InterfaceAbi> = {
  RecordRegistry: recordRegistryAbi as InterfaceAbi,
  ConsentManager: consentManagerAbi as InterfaceAbi,
  ResearchSettlement: researchSettlementAbi as InterfaceAbi,
};

export const CONTRACT_INTERFACES: Record<ContractName, Interface> = {
  RecordRegistry: new Interface(CONTRACT_ABIS.RecordRegistry),
  ConsentManager: new Interface(CONTRACT_ABIS.ConsentManager),
  ResearchSettlement: new Interface(CONTRACT_ABIS.ResearchSettlement),
};

/** A contract bound to a provider (reads) or a MetaMask signer (transactions). */
export function getContract(name: ContractName, runner: ContractRunner): Contract {
  return new Contract(CONTRACT_ADDRESSES[name], CONTRACT_ABIS[name], runner);
}
