# CareConsent — Frontend

Patient dashboard and access history (React + TypeScript + MetaMask).

**Owner:** Elif Naz Akdora · **Second member:** Enes Malik Çolak

## Current status

Project scaffold only: Vite + React + TypeScript build setup, base styles and a placeholder
landing page. Wallet connection, screens and API integration are not implemented yet.

## Run locally

```bash
cd frontend
npm install
cp .env.example .env.local   # optional
npm run dev                  # http://localhost:5173
npm run build                # type check + production build into dist/
```

Requests to `/api/*` are proxied to the Spring Boot gateway on `http://localhost:8080`.
`VITE_USE_MOCK` in `.env.example` is reserved for the planned mock data layer, which will be used
until the backend gateway is ready; it has no effect yet.

## MetaMask + Anvil (for upcoming wallet integration)

1. Start Anvil (`anvil`), which listens on `http://127.0.0.1:8545` with chain id `31337`.
2. In MetaMask add a network: RPC `http://127.0.0.1:8545`, chain id `31337`, symbol `ETH`.
3. Import one of the test private keys printed by Anvil (test accounts only).

A **Connect wallet** button will be added with the wallet integration.

## Structure

Current:

```
index.html     Vite entry page
src/
  main.tsx     application entry (placeholder page)
  styles.css   base styles and colour tokens
```

Planned:

```
src/
  api/         data access (mock first, gateway API later)
  components/  layout, wallet button, status helpers
  pages/       Overview, Records, Grants, AccessHistory
  types/       models: RecordVersion, ConsentGrant, ReleaseReceipt
  wallet/      MetaMask connection (ethers v6)
```

The models will be aligned with the backend API and with the contract interface in
[`docs/contract-interface.md`](../docs/contract-interface.md).

## Planned next steps

- MetaMask connection and wallet-challenge sign-in
- Create and revoke grants with a MetaMask signature
- Verify receipts against their on-chain commitments
- Research-approval screen
