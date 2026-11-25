# CareConsent Smart Contracts

Solidity smart contracts, Foundry test suite, exported ABIs, and Anvil deployment scripts for **CareConsent** (Epics **E2** registry boundary, **E3** patient-controlled consent & audit commitments, and **E6** research sharing & test-credit settlement).

See [docs/contract-interface.md](../docs/contract-interface.md) for full identifier encodings, event schemas, custom errors, and backend/frontend integration rules.

## Contracts

- **`src/RecordRegistry.sol`**: Anchors immutable SHA-256 `ciphertextDigest` values for opaque `versionId`s, supports linked correction versions (`replacesVersionId`), and allows owners to retire versions without mutating historical commitments.
- **`src/ConsentManager.sol`**: Manages patient-signed `ConsentGrant` records (`Treatment` / `Research`), enforces strict expiry boundaries (`block.timestamp < expiresAt`), handles patient revocations, and restricts `recordRelease` audit-receipt anchoring to allowlisted gateway signers.
- **`src/ResearchSettlement.sol`**: Escrows valueless development test credits for research requests, handles patient refusal and expired-request refunds, and pays the patient once per `releaseId` when attested by an allowlisted gateway for a `Purpose.Research` grant.
- **`abi/`**: Generated ABI JSON files (`RecordRegistry.json`, `ConsentManager.json`, `ResearchSettlement.json`) for the Spring Boot EVM adapter and React/MetaMask client.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `anvil`, `cast`)
- Submodule initialized:

```bash
git submodule update --init --recursive
```

## Build, Format, and Test

Run all commands from inside `contracts/`:

```bash
cd contracts
forge fmt --check
forge build
forge test -vvv
```

## Regenerating ABI Artifacts

```bash
cd contracts
forge inspect RecordRegistry abi --json > abi/RecordRegistry.json
forge inspect ConsentManager abi --json > abi/ConsentManager.json
forge inspect ResearchSettlement abi --json > abi/ResearchSettlement.json
```

## Local Anvil Deployment

1. Start Anvil in a terminal (`chainId = 31337`):

```bash
anvil
```

2. Deploy using Anvil default account `#0` as deployer/admin, default account `#1` (`0x70997970C51812dc3A010C7d01b50e0d17dc79C8`) as the allowlisted gateway signer (override with `GATEWAY_ADDRESS`), and default account `#4` (`0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65`) seeded with `1000` test credits (override with `DEMO_RESEARCHER_ADDRESS` / `DEMO_INITIAL_CREDITS`):

```bash
cd contracts
forge script script/DeployCareConsent.s.sol:DeployCareConsent \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```
