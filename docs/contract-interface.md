# CareConsent Contract-to-Gateway Interface Specification

**Module:** Consent contracts and access gateway (Epic E3) & Encrypted storage registry interface (Epic E2)  
**Smart-contract owner:** Hasan Samet Yurtbilir  
**Second member / reviewer:** Bahattin Baran Serin  
**Target Solidity compiler:** `0.8.24` (EVM `paris`)  
**Target local development network:** Anvil (`chainId = 31337`)

---

## 1. Purpose and Scope Boundary

This document defines the exact on-chain interface, identifier encodings, events, custom errors, and trust boundaries shared between:

- **`contracts/` (Smart-contract owner):** Solidity contracts (`RecordRegistry`, `ConsentManager`), custom errors, events, Foundry unit/rejection tests, Anvil deployment scripts, and exported ABI JSON artifacts (`contracts/abi/`).
- **`backend/` (Backend owner):** Java Spring Boot EVM adapter, gateway consent enforcement, AES-256-GCM encryption/decryption pipeline, private IPFS adapter, and temporary Apache Jena SPARQL execution.
- **`frontend/` (Frontend owner):** React/TypeScript UI and MetaMask transaction signing for patients (`registerVersion`, `retireVersion`, `grantAccess`, `revokeGrant`) and off-chain wallet-challenge authentication.

The patient wallet signs record registrations, retirements, grants, and revocations directly against the contracts. The Spring Boot gateway cannot forge patient consent; it reads confirmed contract state, enforces access control before any decryption, rechecks consent immediately prior to release, and anchors encrypted release-receipt commitments via an allowlisted gateway signer address.

---

## 2. Privacy Invariants (On-Chain vs. Off-Chain)

| Data Element | Stored On-Chain? | Stored Off-Chain? | Notes |
|---|---|---|---|
| Wallet addresses (`owner`, `grantee`, `gateway`, `admin`) | Yes | Yes | Development/synthetic Anvil accounts only |
| Opaque `bytes32` identifiers (`versionId`, `grantId`, `releaseId`) | Yes | Yes | Must not encode plaintext names, national IDs, or clinical values |
| `ciphertextDigest` (`bytes32` SHA-256 of encrypted envelope bytes) | Yes | Yes | Anchors integrity independently of RDF serialization order |
| `replacesVersionId` (`bytes32` parent pointer, or `0x00..00`) | Yes | Yes | Links corrected versions without mutating prior commitments |
| `scopeCommitment` (`bytes32` hash of permitted `versionId[]`) | Yes | Yes | Hides exact version counts and lists on chain |
| `Purpose` (`Treatment = 1`, `Research = 2`), `expiresAt`, `revoked` | Yes | Yes | Enforced on chain and verified by gateway |
| `receiptCommitment` (`bytes32` SHA-256 of encrypted `ReleaseReceipt`) | Yes | Yes | Reconciled in patient sharing history dashboard |
| Raw IPFS CIDs (`Qm...` / `bafy...`) | **NEVER** | Yes (StorageManifest) | Must never appear in calldata, contract storage, events, or routine logs |
| AES-256-GCM keys / nonces / wrapped key references | **NEVER** | Yes (Key Service) | Isolated from blockchain and logs |
| FHIR JSON / RDF triples / clinical text / plaintext patient IDs | **NEVER** | Yes (Encrypted IPFS + temporary Jena) | Plaintext never persists on chain or in routine application logs |

---

## 3. Identifier, Enum, and Commitment Formats

All identifiers and commitments are fixed-width `bytes32` values (`0x` + 64 hex characters in JSON/Java). Zero (`bytes32(0)`) is reserved as an invalid sentinel (except `replacesVersionId`, where `bytes32(0)` means an initial version with no predecessor).

### 3.1 Canonical Values and Hash Constructions

| Field | Type | Canonical Construction |
|---|---|---|
| `versionId` | `bytes32` | Opaque identifier generated off-chain, e.g. `sha256("CareConsent:Version:v1:" || uuid)` |
| `ciphertextDigest` | `bytes32` | `sha256(exactEncryptedEnvelopeBytes)` covering the authenticated AES-256-GCM envelope stored on IPFS |
| `grantId` | `bytes32` | Unique per grant to prevent replay, e.g. `keccak256(abi.encode(chainId, consentManagerAddress, patientAddress, requestId))` |
| `scopeCommitment` | `bytes32` | `keccak256(abi.encode(patientAddress, sortedVersionIds))` where `sortedVersionIds` is a non-empty, duplicate-free `bytes32[]` sorted strictly ascending by unsigned 256-bit integer value |
| `releaseId` | `bytes32` | Unique per gateway release attempt, e.g. `sha256("CareConsent:Release:v1:" || releaseUuid)` |
| `receiptCommitment` | `bytes32` | `sha256(exactEncryptedReleaseReceiptBytes)` matching the private off-chain `ReleaseReceipt` |

> **Java / TypeScript interoperability note for `scopeCommitment`:**  
> Both backend (web3j / ethers-compatible ABI encoding) and frontend (`ethers.AbiCoder.defaultAbiCoder().encode(["address", "bytes32[]"], [patientAddress, sortedVersionIds])`) MUST sort `versionIds` in strictly ascending byte order, reject duplicates and zero entries, and hash the standard ABI encoding (`keccak256`).

### 3.2 Enumerations

#### `Purpose` (`uint8`)
| Value | Name | Meaning |
|---|---|---|
| `0` | `None` | Invalid sentinel; rejected on grant creation and access checks |
| `1` | `Treatment` | Clinical care access by a named clinician |
| `2` | `Research` | Separately approved research export (cannot be satisfied by `Treatment` grant) |

#### `GrantStatus` (`uint8`)
| Value | Name | Meaning |
|---|---|---|
| `0` | `NotFound` | No grant exists for `grantId` |
| `1` | `Active` | Exists, `revoked == false`, and `block.timestamp < expiresAt` |
| `2` | `Expired` | Exists, `revoked == false`, and `block.timestamp >= expiresAt` |
| `3` | `Revoked` | Exists and `revoked == true` (takes precedence in status display) |

> Note: `Pending` and `Refused` are off-chain `AccessRequest` states managed by the gateway before a patient signs a transaction on chain.

### 3.3 Expiry Boundary Semantics

- Grants require `expiresAt > block.timestamp` at creation time.
- Authorization requires **strict inequality**: `block.timestamp < expiresAt`.
  - At `T = expiresAt - 1`: grant is `Active` and may authorize access.
  - At `T = expiresAt`: grant is `Expired` and MUST fail authorization.
- Timestamps (`registeredAt`, `grantedAt`, `expiresAt`, `revokedAt`, `recordedAt`) use `uint64` Unix epoch seconds (UTC).

---

## 4. Contract Interfaces

### 4.1 `RecordRegistry` (`IRecordRegistry`)

Manages immutable ciphertext integrity commitments for patient-owned health record versions.

#### Structs
```solidity
struct RecordVersion {
    address owner;
    bytes32 ciphertextDigest;
    bytes32 replacesVersionId;
    uint64 registeredAt;
    bool retired;
}
```

#### Functions
| Function | Caller | Behavior & Validation |
|---|---|---|
| `registerVersion(bytes32 versionId, bytes32 ciphertextDigest, bytes32 replacesVersionId)` | Patient (`msg.sender`) | Reverts if `versionId == 0`, `ciphertextDigest == 0`, or `versionId` already exists. If `replacesVersionId != 0`, verifies that predecessor exists and `owner == msg.sender`. Stores immutable commitment with `retired = false`. |
| `retireVersion(bytes32 versionId)` | Version owner (`msg.sender`) | Reverts if missing, `owner != msg.sender`, or already retired. Sets `retired = true` while preserving `ciphertextDigest` and `replacesVersionId` for auditability. |
| `getVersion(bytes32 versionId) view returns (RecordVersion memory)` | Any | Returns stored `RecordVersion`; reverts `VersionNotFound` if missing. |
| `versionExists(bytes32 versionId) view returns (bool)` | Any | Returns `true` iff `versionId` has been registered. |
| `ownerOf(bytes32 versionId) view returns (address)` | Any | Returns owner address (`address(0)` if unregistered). |
| `verifyDigest(bytes32 versionId, bytes32 ciphertextDigest) view returns (bool)` | Any | Returns `true` iff `versionId` exists, `ciphertextDigest != 0`, and stored digest matches. |

#### Events
- `VersionRegistered(bytes32 indexed versionId, address indexed owner, bytes32 ciphertextDigest, bytes32 indexed replacesVersionId, uint64 registeredAt)`
- `VersionRetired(bytes32 indexed versionId, address indexed owner, uint64 retiredAt)`

#### Custom Errors
- `InvalidVersionId()`
- `InvalidCiphertextDigest()`
- `VersionAlreadyRegistered(bytes32 versionId)`
- `ReplacedVersionNotFound(bytes32 replacesVersionId)`
- `VersionNotFound(bytes32 versionId)`
- `NotVersionOwner(bytes32 versionId, address caller)`
- `VersionAlreadyRetired(bytes32 versionId)`

---

### 4.2 `ConsentManager` (`IConsentManager`)

Manages patient-signed consent grants, gateway allowlisting, permission checks, and on-chain release-receipt commitments.

#### Structs
```solidity
struct ConsentGrant {
    address owner;
    address grantee;
    Purpose purpose;
    bytes32 scopeCommitment;
    uint64 grantedAt;
    uint64 expiresAt;
    bool revoked;
    uint64 revokedAt;
}

struct ReleaseCommitment {
    bytes32 grantId;
    address gateway;
    address grantee;
    Purpose purpose;
    bytes32 receiptCommitment;
    uint64 recordedAt;
}
```

#### Functions
| Function | Caller | Behavior & Validation |
|---|---|---|
| `setGatewayAuthorization(address gateway, bool authorized)` | `admin` | Reverts `UnauthorizedAdmin` if caller is not `admin`, `InvalidGatewayAddress` if `gateway == 0`. Updates `authorizedGateways[gateway]` and emits event. |
| `grantAccess(bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment, uint64 expiresAt)` | Patient (`msg.sender`) | Reverts if `grantId == 0`, duplicate `grantId`, `grantee == 0` or `grantee == msg.sender`, `purpose == Purpose.None`, `scopeCommitment == 0`, or `expiresAt <= block.timestamp`. Stores grant and emits `GrantCreated`. |
| `revokeGrant(bytes32 grantId)` | Grant owner (`msg.sender`) | Reverts if missing, `owner != msg.sender`, already `revoked`, or `block.timestamp >= expiresAt`. Marks `revoked = true`, records `revokedAt`, emits `GrantRevoked`. |
| `getGrant(bytes32 grantId) view returns (ConsentGrant memory)` | Any | Returns stored `ConsentGrant`; reverts `GrantNotFound` if absent. |
| `getGrantStatus(bytes32 grantId) view returns (GrantStatus)` | Any | Returns `NotFound`, `Revoked`, `Expired` (`block.timestamp >= expiresAt`), or `Active`. |
| `isAccessAuthorized(bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment) view returns (bool)` | Any | Returns `true` iff grant exists, `!revoked`, `block.timestamp < expiresAt`, `grantee`, `purpose`, and `scopeCommitment` all match. |
| `recordRelease(bytes32 releaseId, bytes32 grantId, address grantee, Purpose purpose, bytes32 scopeCommitment, bytes32 receiptCommitment)` | Allowlisted gateway | Reverts if caller is not an authorized gateway, `releaseId == 0`, `receiptCommitment == 0`, or `releaseId` was already recorded. Atomically validates the grant (`exists`, `!revoked`, `block.timestamp < expiresAt`, `grantee`, `purpose`, `scopeCommitment`). Stores `ReleaseCommitment` and emits `ReleaseRecorded`. |
| `releaseExists(bytes32 releaseId) view returns (bool)` | Any | Returns `true` iff `releaseId` is anchored. |
| `getRelease(bytes32 releaseId) view returns (ReleaseCommitment memory)` | Any | Returns stored `ReleaseCommitment`; reverts `ReleaseNotFound` if absent. |
| `verifyReceiptCommitment(bytes32 releaseId, bytes32 receiptCommitment) view returns (bool)` | Any | Returns `true` iff `releaseId` exists, `receiptCommitment != 0`, and stored commitment matches. |

#### Events
- `GatewayAuthorizationUpdated(address indexed gateway, bool authorized)`
- `GrantCreated(bytes32 indexed grantId, address indexed owner, address indexed grantee, Purpose purpose, bytes32 scopeCommitment, uint64 expiresAt, uint64 grantedAt)`
- `GrantRevoked(bytes32 indexed grantId, address indexed owner, uint64 revokedAt)`
- `ReleaseRecorded(bytes32 indexed releaseId, bytes32 indexed grantId, address indexed grantee, Purpose purpose, bytes32 receiptCommitment, address gateway, uint64 recordedAt)`

#### Custom Errors
- `UnauthorizedAdmin(address caller)`
- `InvalidGatewayAddress()`
- `UnauthorizedGateway(address caller)`
- `InvalidGrantId()`
- `GrantAlreadyExists(bytes32 grantId)`
- `InvalidGrantee()`
- `InvalidPurpose()`
- `InvalidScopeCommitment()`
- `ExpiryNotInFuture(uint64 expiresAt, uint64 currentTime)`
- `GrantNotFound(bytes32 grantId)`
- `NotGrantOwner(bytes32 grantId, address caller)`
- `GrantAlreadyRevoked(bytes32 grantId)`
- `GrantAlreadyExpired(bytes32 grantId)`
- `InvalidReleaseId()`
- `InvalidReceiptCommitment()`
- `ReleaseAlreadyRecorded(bytes32 releaseId)`
- `ReleaseNotFound(bytes32 releaseId)`
- `GrantIsRevoked(bytes32 grantId)`
- `GrantIsExpired(bytes32 grantId)`
- `GranteeMismatch(bytes32 grantId, address expected, address actual)`
- `PurposeMismatch(bytes32 grantId, Purpose expected, Purpose actual)`
- `ScopeMismatch(bytes32 grantId)`

---

## 5. Planned Epic E6 Interface Preview (`ResearchSettlement`)

> **Status:** *Planned — Epic E6 (to be implemented after E2 storage and E3 consent integration).*

The upcoming `ResearchSettlement` contract will integrate cleanly with `ConsentManager` without changing the `ConsentManager` ABI:

1. A researcher funds a test-credit request (`fundResearchRequest(bytes32 requestId, address patient, uint256 fee, uint64 expiresAt)` or equivalent test-credit vault).
2. The patient creates a `ConsentGrant` with `Purpose.Research` (`purpose = 2`) in `ConsentManager`.
3. Once the gateway completes export preparation, rechecks consent, and anchors `recordRelease(releaseId, grantId, researcher, Purpose.Research, scopeCommitment, receiptCommitment)` on `ConsentManager`, the gateway calls `settleResearch(bytes32 releaseId)` (or `settleResearch(bytes32 requestId, bytes32 releaseId)`).
4. `ResearchSettlement` will verify via `IConsentManager`:
   - `releaseExists(releaseId)` is `true` and `getRelease(releaseId)` shows `purpose == Purpose.Research` and an authorized `gateway`.
   - `getGrant(release.grantId).owner` matches the funded patient payout address.
   - `releaseId` has never been settled before (strict idempotency; duplicate calls revert).
5. Unused expired requests will support refunding to the researcher. All credits are valueless local Anvil development credits.

---

## 6. Local Anvil Convention and Artifacts

| Parameter | Local Default |
|---|---|
| Chain ID | `31337` |
| RPC URL | `http://127.0.0.1:8545` |
| Account `#0` (`0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`) | Contract deployer & `ConsentManager.admin` |
| Account `#1` (`0x70997970C51812dc3A010C7d01b50e0d17dc79C8`) | Default allowlisted gateway signer (`GATEWAY_ADDRESS`) |
| Accounts `#2+` | Synthetic Patient, Clinician, and Researcher test wallets |
| ABI artifacts | `contracts/abi/RecordRegistry.json`, `contracts/abi/ConsentManager.json` |
| Deployment script | `contracts/script/DeployCareConsent.s.sol` |
