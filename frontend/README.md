# CareConsent — Frontend

Patient dashboard and access history (React + TypeScript + MetaMask).

**Owner:** Elif Naz Akdora · **Second member:** Enes Malik Çolak

## Current status

- Patient record list with synthetic mock data
- Version list per record with multi-version selection (retired versions cannot be selected)
- Live `scopeCommitment` preview for the selected versions, computed as the consent contract expects
- Separate messages for loading, empty result and service unavailable (S12)
- MetaMask connection, Anvil network check/switch, address and role badge, wallet-challenge
  sign-in (browser-side mock verification until the gateway exists)

Not implemented yet: grant creation/revocation, clinician and researcher screens, gateway API
integration.

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
(Anvil account #2). Use the **Records / Empty / Service error** switch on the page, or open
`?demo=empty` / `?demo=unavailable`, to check each result state by hand.

With `VITE_USE_MOCK=false` the app reports the record service as unavailable, because the
gateway endpoints are not defined yet; it never falls back to invented data silently.

## MetaMask + Anvil

1. Start Anvil (`anvil`), which listens on `http://127.0.0.1:8545` with chain id `31337`.
2. Import one of the test private keys printed by Anvil into MetaMask (test accounts only).
   Account #2 shows as Patient, #3 as Clinician, #4 as Researcher.
3. Click **Connect wallet**. If MetaMask is on another network, a warning bar appears; click
   **Switch to Anvil (local)** (the app offers to add the network if MetaMask does not know it).
4. Click **Sign in** and sign the message in MetaMask. The message is bound to this site, the
   account, chain 31337, a one-time nonce and a 5-minute expiry. It sends no transaction.

Notes:

- Sign-in is checked **in the browser** while `VITE_USE_MOCK=true` (badge: "Signed in · mock
  check"). This shows the flow works but is not a security check; the gateway must verify the
  signature once its auth endpoints exist. With `VITE_USE_MOCK=false` sign-in fails closed.
- The role badge comes from the Anvil account convention in `docs/contract-interface.md` §6 and
  is display only. Real roles will come from the gateway.
- Changing account or network in MetaMask ends the session. A session lasts 30 minutes.

## Structure

```
index.html                 Vite entry page
src/
  main.tsx                 React entry
  App.tsx                  patient records page: loading, record list, versions, selection
  styles.css               styles and colour tokens
  api/records.ts           record data access (mock source, demo scenarios)
  mocks/mockData.ts        synthetic patient records and versions, Anvil test accounts
  types/models.ts          contract-aligned types, grant status rule, scopeCommitment
  components/
    RecordList.tsx         record list
    VersionPanel.tsx       versions of the open record with checkboxes
    SelectionSummary.tsx   selected versions and scopeCommitment preview
    StatusMessage.tsx      EmptyState, ServiceUnavailable, Loading
    WalletControls.tsx     top-bar wallet button/badge, network and error banners
    format.ts              date and hex formatting helpers
  wallet/
    wallet.ts              MetaMask connection, chain check, roles, wallet-challenge sign-in
    useWallet.ts           React hook: wallet state, account/chain change handling, session
```

## Alignment with the contracts

`src/types/models.ts` follows [`docs/contract-interface.md`](../docs/contract-interface.md) and
`contracts/src/interfaces/*.sol`:

- `Purpose`, `GrantStatus` and `RequestStatus` use the same `uint8` values as the Solidity enums.
- `grantStatusAt` applies the contract rule: revoked first, expired when `now >= expiresAt`.
- `computeScopeCommitment(patient, versionIds)` = `keccak256(abi.encode(address, bytes32[]))`
  with version IDs sorted strictly ascending; empty lists, zero IDs and duplicates are rejected.
- Mock `versionId`s follow `sha256("CareConsent:Version:v1:" || uuid)`. Mock `ciphertextDigest`s
  are stand-in hashes, because no encrypted envelopes exist until the storage pipeline is ready.

Off-chain display fields (summary, clinical date, receipt details) are a draft and must be aligned
with the backend API.

## Planned next steps

- Replace mock sign-in with the gateway challenge/verify endpoints
- Create and revoke grants with a MetaMask signature
- Verify receipts against their on-chain commitments
- Clinician and researcher screens
