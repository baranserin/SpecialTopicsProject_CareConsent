# CareConsent — Frontend

Patient dashboard and access history (React + TypeScript + MetaMask).

**Owner:** Elif Naz Akdora · **Second member:** Enes Malik Çolak

## Current status

- Patient record list with synthetic mock data
- Version list per record with multi-version selection (retired versions cannot be selected)
- Live `scopeCommitment` preview for the selected versions, computed as the consent contract expects
- Separate messages for loading, empty result, access denied and service unavailable (S12)
- MetaMask connection, Anvil network check/switch, address and role badge, disconnect
- Wallet-challenge sign-in (browser-side mock verification until the gateway exists)
- Records page only for the signed-in owner; other roles see an access-denied message
- Network & contracts check: chain reachable, chain time, contracts deployed, balances
- Shared transaction helper for MetaMask-signed contract calls (confirmation tracking and
  readable custom-error messages), ready for the grant screens

- Grant creation (P3): choose a recipient and expiry for the selected versions, sign grantAccess in MetaMask,
  see each transaction phase, and read the confirmed grant back from the chain

Not implemented yet: grant revocation and grant list screens, clinician and researcher screens, gateway
API integration.

## Run locally

```bash
cd frontend
npm install
cp .env.example .env.local   # optional
npm run dev                  # http://localhost:5173
npm run build                # type check + production build into dist/
```

Requests to `/api/*` are proxied to the Spring Boot gateway on `http://localhost:8080`.

### Mock data and demo states

With `VITE_USE_MOCK=true` (the default) the app shows synthetic records for patient P01
(Anvil account #2) after sign-in. Without a wallet, **Preview with synthetic data** opens the
same page in a clearly marked preview. Use the **Records / Empty / Service error** switch, or open
`?demo=empty` / `?demo=unavailable`, to check each result state by hand.

With `VITE_USE_MOCK=false` the app reports the record service as unavailable and sign-in fails
closed, because the gateway endpoints are not defined yet; it never falls back to invented data.

## MetaMask + Anvil

### 1. Start the chain and deploy the contracts

```bash
anvil                                    # terminal 1: http://127.0.0.1:8545, chain 31337
cd contracts                             # terminal 2
forge script script/DeployCareConsent.s.sol:DeployCareConsent \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

On a fresh Anvil, the deploy script produces the default addresses built into the app
(`src/chain/contracts.ts`). If you deployed anything before it, copy the three addresses the
script prints into `frontend/.env.local` (`VITE_RECORD_REGISTRY_ADDRESS`, ...).

The ABIs are imported directly from `contracts/abi/`; regenerate them there, not in `frontend/`.

### 2. MetaMask

1. Import Anvil test private keys into MetaMask (test accounts only). Account #2 shows as
   Patient, #3 as Clinician, #4 as Researcher.
2. Click **Connect wallet**. On another network a warning bar appears; click
   **Switch to Anvil (local)** (the app offers to add the network if MetaMask does not know it).
3. Click **Sign in** and sign the message. It is bound to this site, the account, chain 31337, a
   one-time nonce and a 5-minute expiry. It sends no transaction.
4. Open **Network & contracts** to see block number, chain time, balances and whether all three
   contracts are deployed.

Notes:

- Sign-in is checked **in the browser** while `VITE_USE_MOCK=true` (badge: "Signed in · mock
  check"). This shows the flow works but is not a security check; the gateway (E2) must verify
  the signature once its auth endpoints exist.
- The role badge comes from the Anvil account convention in `docs/contract-interface.md` §6 and
  is display only. Real roles will come from the gateway.
- Changing account or network ends the session; a sign-in that finishes after such a change is
  discarded. A session lasts 30 minutes.
- **Disconnect** forgets the account and asks MetaMask to revoke this site's permission.

### 3. Manual test checklist

| # | Step | Expected |
|---|---|---|
| 1 | Open the app with MetaMask disabled | "MetaMask not detected" + Install link |
| 2 | Enable MetaMask, click Connect wallet, approve | Address badge with role appears |
| 3 | Put MetaMask on another network | Amber dot, warning bar, Sign in disabled |
| 4 | Click Switch to Anvil (local) | Warning disappears, green dot |
| 5 | Sign in with account #2, sign the message | "Signed in · mock check", records page visible |
| 6 | Reject the signature instead | "The request was rejected in MetaMask." |
| 7 | Switch MetaMask to account #3 | Session ends; after sign-in: access-denied message, no records |
| 8 | Stop Anvil, click Refresh in Network & contracts | "Chain not reachable" |
| 9 | Restart Anvil without deploying, Refresh | "Contracts missing", each contract "no code" |
| 10 | Deploy, Refresh | Three contracts "deployed", researcher #4 shows 1000 test credits |
| 11 | Click Disconnect | Back to Connect wallet |

Troubleshooting: after restarting Anvil, MetaMask may keep old nonces. Use MetaMask
Settings → Advanced → **Clear activity tab data** for the account.

## Structure

```
index.html                 Vite entry page
src/
  main.tsx                 React entry
  App.tsx                  top bar, sign-in gate, access decision for the records page
  styles.css               styles and colour tokens
  pages/PatientRecords.tsx loading, record list, versions, selection, demo states
  api/records.ts           record data access (mock source, demo scenarios)
  mocks/mockData.ts        synthetic patient records and versions, Anvil test accounts
  types/models.ts          contract-aligned types, grant status rule, scopeCommitment
  chain/
    contracts.ts           contract addresses (env or fresh-Anvil defaults) and ABIs
    chainStatus.ts         chain reachable, chain time, deployed contracts, balances
    transactions.ts        MetaMask transaction phases and custom-error messages
  components/
    RecordList.tsx         record list
    VersionPanel.tsx       versions of the open record with checkboxes
    SelectionSummary.tsx   selected versions and scopeCommitment preview
    StatusMessage.tsx      EmptyState, ServiceUnavailable, AccessDenied, Loading
    WalletControls.tsx     top-bar wallet button/badge, network and error banners
    ChainStatusPanel.tsx   Network & contracts panel
    format.ts              date and hex formatting helpers
  wallet/
    wallet.ts              MetaMask connection, chain check, roles, wallet-challenge sign-in
    useWallet.ts           React hook: wallet state, account/chain change handling, session
```

## Alignment with the contracts

`src/types/models.ts` follows [`docs/contract-interface.md`](../docs/contract-interface.md) and
`contracts/src/interfaces/*.sol`:

- `Purpose`, `GrantStatus` and `RequestStatus` use the same `uint8` values as the Solidity enums.
- `grantStatusAt` applies the contract rule: revoked first, expired when `now >= expiresAt`,
  where `now` is the chain time shown in the Network & contracts panel.
- `computeScopeCommitment(patient, versionIds)` = `keccak256(abi.encode(address, bytes32[]))`
  with version IDs sorted strictly ascending; empty lists, zero IDs and duplicates are rejected.
- Mock `versionId`s follow `sha256("CareConsent:Version:v1:" || uuid)`. Mock `ciphertextDigest`s
  are stand-in hashes, because no encrypted envelopes exist until the storage pipeline is ready.
- `src/chain/transactions.ts` maps the contracts' custom errors (from the ABIs) to plain text.

Off-chain display fields (summary, clinical date, receipt details) are a draft and must be aligned
with the backend API.

## Planned next steps

- Replace mock sign-in with the gateway challenge/verify endpoints
- Revoke grants and list them (`revokeGrant`)
- Verify receipts against their on-chain commitments
- Clinician and researcher screens
