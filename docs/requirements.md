# CareConsent - System Requirements

## 1. Introduction

### 1.1 Purpose

This document defines the functional and non-functional
requirements of the CareConsent system.

It provides a common reference for system development,
integration, verification and acceptance testing.

### 1.2 System Overview

CareConsent is a patient-controlled health data sharing
prototype that combines blockchain technology, encrypted
off-chain storage and semantic technologies.

The system enables patients to manage selected health records,
control access permissions and review gateway release receipts.

Clinicians can perform predefined clinical queries, while
researchers can request separately authorised data exports.

### 1.3 Scope

The system operates within the following boundaries:

- Synthetic health records only.
- Local Ethereum-compatible development network.
- Private IPFS storage.
- Patient-controlled and purpose-specific consent.
- Five predefined clinical query templates.
- Research compensation using valueless test credits.
- No real medical decisions or commercial transactions.

### 1.4 User Roles

| Persona ID | Role | Responsibility |
| --- | --- | --- |
| UP-01 | Patient | Manage records and access permissions |
| UP-02 | Clinician | Review authorised health information |
| UP-03 | Researcher | Request separately approved research data |

Detailed user profiles are defined in
[User Personas](user-personas.md).

### 1.5 Requirement Identification

- FR: Functional Requirement.
- NFR: Non-functional Requirement.
- S: User Story defined in the project proposal.
- UP: User Persona.

The requirements describe expected system behaviour.
They do not represent completed implementation or passed tests.

## 2. Functional Requirements

### 2.1 Authentication and User Roles

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-01 | The system shall support separate authenticated Patient, Clinician and Researcher roles. | Cross-cutting |
| FR-02 | The system shall authenticate wallet users through a short-lived signature challenge bound to the session and development chain without collecting wallet private keys. | S3, S5, S9 |

### 2.2 Health Record Management

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-03 | The system shall allow patients to import supported synthetic FHIR R4 Condition, MedicationStatement, AllergyIntolerance and Observation records. | S1 |
| FR-04 | The system shall validate imported records using the defined validation rules and SHACL shapes, rejecting invalid records with specific errors before registration. | S1 |
| FR-05 | The system shall create a traceable RDF representation of each accepted record, preserving its source and version information. | S1 |

### 2.3 Encryption, Storage and Integrity

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-06 | The system shall encrypt each accepted record version using AES-256-GCM with a fresh encryption key and nonce. | S2, S11 |
| FR-07 | The system shall store encrypted record envelopes on private IPFS nodes and retain their CIDs in a protected off-chain manifest. | S2 |
| FR-08 | The system shall register the SHA-256 digest of the exact encrypted envelope bytes together with an opaque record-version identifier on the local blockchain. | S2 |
| FR-09 | The system shall verify the retrieved ciphertext digest before authenticated decryption. A digest mismatch or decryption failure shall prevent plaintext release. | S2 |

### 2.4 Consent and Access Control

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-10 | The system shall allow clinicians to request access and patients to approve or refuse requests for selected health record versions. | S3, S5 |
| FR-11 | The system shall allow a patient to sign a consent grant specifying the recipient, purpose, explicit record-version list and expiry time. The immutable version list shall be bound through a scope commitment, and the gateway shall verify the requested scope against that commitment before authorising access. | S3 |tam
| FR-12 | The system shall deny access if the grant is absent, revoked, expired, assigned to another recipient or purpose, or excludes any requested record version. Access at the exact expiry time shall be denied. | S3, S4 |
| FR-13 | The system shall allow patients to revoke existing grants. Once revocation is confirmed, subsequent release checks shall deny access under that grant. | S4 |
| FR-14 | The system shall display pending, active, refused, expired and revoked access states without revealing health fields before permission becomes active. | S5 |
| FR-15 | The system shall register corrected records as new versions with fresh encryption keys, nonces and digests. Existing grants shall not automatically include new versions. | S11 |

### 2.5 Clinical Query Workspace

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-16 | The system shall allow authorised clinicians to execute only five predefined, parameter-bound SPARQL clinical query templates. Arbitrary SPARQL text, update operations and SERVICE federation requests shall be rejected. | S6, S7 |
| FR-17 | The system shall decrypt only authorised record versions into a temporary consent-scoped dataset and return only the permitted result projection. The temporary dataset shall be closed and discarded after both successful and failed operations. | S6, S7, S12 |
| FR-18 | The antibiotic query shall identify permitted MedicationStatement records whose recorded use overlaps the previous twelve months, exclude entered-in-error records and include source dates and versions. A prescription alone shall not be treated as confirmed use. | S6 |
| FR-19 | The four remaining templates shall return permitted active conditions, active allergies, dated symptom observations and exercise observations, with traceable source information. | S7 |

### 2.6 Audit and Access History

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-20 | The system shall repeat consent verification immediately before data release and require a confirmed blockchain receipt commitment before sending clinical content. | S4, S8, S12 |
| FR-21 | The system shall allow patients to inspect gateway release receipts containing recipient, purpose, record versions, time and a commitment matching a confirmed blockchain event. Receipts shall not be presented as proof of human viewing or onward sharing. | S8 |

### 2.7 Research Sharing and Test-Credit Settlement

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-22 | The system shall allow researchers to request a one-patient dataset specifying the research purpose, selected record versions, requested fields, expiry and test-credit fee. | S9 |
| FR-23 | The system shall require separate patient approval and a valid research grant before releasing a research export. A treatment grant shall not authorise research access. Direct-identifier fields shall be excluded from the research projection. | S9 |
| FR-24 | The system shall require sufficient funded test credits and a valid release attestation from the trusted gateway before crediting the agreed fee to the patient. | S10 |
| FR-25 | The system shall prevent duplicate settlement for the same release identifier and provide a traceable settlement event. Unfunded, unauthorised and expired requests shall not produce a payment. | S10 |

### 2.8 Error Handling and Safe Release

| ID | Requirement | Related Story |
| --- | --- | --- |
| FR-26 | The system shall fail closed when storage, the key service, ciphertext integrity verification, the blockchain connection or audit confirmation cannot support a safe release. No clinical content shall be returned and no research settlement shall occur for a failed release. | S12 |
| FR-27 | The system shall distinguish between an empty permitted result, denied access and service unavailability, and support safe retries without duplicate settlement. | S7, S12 |


  

  


## 3. Non-functional Requirements

### 3.1 Security

| ID | Requirement |
| --- | --- |
| NFR-01 | Stored health record contents shall be protected using authenticated AES-256-GCM encryption. Each new record version shall use a fresh encryption key and nonce. |
| NFR-02 | Access control shall be enforced at the gateway and relevant smart contract boundaries. Direct API requests shall not bypass consent restrictions. |
| NFR-03 | Wallet authentication challenges shall use a nonce, domain, chain identifier and short expiry to prevent replay attacks. |
| NFR-04 | Encryption keys shall be protected by the off-chain key service. Wallet private keys shall not be collected by the application. |

### 3.2 Privacy

| ID | Requirement |
| --- | --- |
| NFR-05 | Clinical text, plaintext patient identifiers, encryption keys, wallet private keys and raw IPFS CIDs shall not be exposed through blockchain transactions or contract storage. |
| NFR-06 | Routine application logs shall not contain plaintext clinical information, plaintext patient identifiers, encryption keys, wallet private keys or raw IPFS CIDs. |
| NFR-07 | Clinical query results and research exports shall contain only authorised patient records, record versions and permitted fields. No cross-patient or out-of-scope information shall be disclosed. |

### 3.3 Performance

| ID | Requirement |
| --- | --- |
| NFR-08 | The 95th percentile (p95) response time shall not exceed 3 seconds across 100 authorised local clinical query requests on a documented test machine, excluding initial record import. |

### 3.4 Reliability and Correctness

| ID | Requirement |
| --- | --- |
| NFR-09 | The validation and mapping pipeline shall successfully process 50 synthetic patient profiles and 1,000 valid clinical resources. All 20 deliberately malformed fixtures shall be rejected with specific reasons. |
| NFR-10 | The encrypted storage pipeline shall complete 1,000 successful round trips for valid record versions and reject all 20 specified tampered-envelope or wrong-key cases. |
| NFR-11 | The access-control evaluation shall include at least 20 cases. All specified denial cases shall return no clinical result or decryption key, and all specified valid cases shall succeed when dependencies are available. |
| NFR-12 | The five clinical query templates shall match the expected results of all 10 manually labelled synthetic query fixtures. |
| NFR-13 | All successful gateway release attempts shall have matching confirmed blockchain receipt commitments. |
| NFR-14 | All 10 research settlement test cases shall match their expected outcomes. Approved releases shall credit the agreed fee exactly once, while denied or unfunded requests shall transfer nothing. |

### 3.5 Usability

| ID | Requirement |
| --- | --- |
| NFR-15 | The patient interface shall support responsive browser-based interaction on smartphones and laptops, while clinician and researcher workspaces shall support their intended desktop usage. |
| NFR-16 | The interfaces shall clearly distinguish successful, empty, denied and unavailable states. Consent screens shall communicate the recipient, purpose, selected record versions and expiry. |

### 3.6 Maintainability and Traceability

| ID | Requirement |
| --- | --- |
| NFR-17 | Source code, interface documentation, semantic models, test fixtures and setup instructions shall be maintained under version control. Each module shall have a designated owner. |
| NFR-18 | Implemented features shall be traceable to the planned project epics, user stories and applicable requirements. Acceptance results shall be supported by actual test evidence. |

### 3.7 Reproducibility

| ID | Requirement |
| --- | --- |
| NFR-19 | A second team member shall be able to follow the documented setup instructions, deploy the local prototype and repeat the synthetic demonstration. |

### 3.8 Scope Compliance

| ID | Requirement |
| --- | --- |
| NFR-20 | All evaluation fixtures shall use synthetic data. The prototype shall not require real patient records, live hospital integrations, public-chain production deployment, real-money payments or clinical decision support. |

## 4. Acceptance Targets

The following targets are derived from the project proposal.
They define planned evaluation criteria, not achieved results.

| Objective | Acceptance Target | Related Requirements |
| --- | --- | --- |
| O1 - Record validation | 50 synthetic patients, 1,000 valid clinical resources and 20 of 20 malformed fixtures rejected | FR-03 to FR-05, NFR-09 |
| O2 - Encrypted storage | 1,000 successful encrypted round trips, 20 of 20 tampered or wrong-key cases rejected, no plaintext clinical fields in inspected chain data and application logs | FR-06 to FR-09, FR-15, NFR-01, NFR-05, NFR-06, NFR-10 |
| O3 - Access control | At least 20 test cases with 100% of specified denial cases blocked without disclosure and all valid cases successful when dependencies are available | FR-10 to FR-15, FR-20, NFR-02, NFR-11 |
| O4 - Query accuracy and audit | 10 of 10 query fixtures matched, no out-of-scope results, 100% receipt reconciliation and p95 response time of at most 3 seconds | FR-16 to FR-21, NFR-07, NFR-08, NFR-12, NFR-13 |
| O5 - Research settlement | 10 of 10 settlement cases matched, with exactly-once payment for approved releases | FR-22 to FR-25, NFR-14 |
| O6 - Scope and reproducibility | Every merged feature aligned with a planned epic, synthetic acceptance fixtures only and no excluded integrations or real-money features | NFR-17 to NFR-20 |

Actual test results and supporting evidence will be recorded
in the acceptance test report after execution.

## 5. System Constraints and Trust Assumptions

- The blockchain environment is a local development network
  using Solidity contracts and Anvil.
- Health record contents are stored as encrypted envelopes
  on private IPFS nodes.
- The gateway and key service are trusted components capable
  of processing plaintext.
- The prototype does not claim fully decentralised or trustless
  health data processing.
- A blockchain digest verifies the integrity of the associated
  encrypted envelope, not the medical accuracy of its contents.
- Consent revocation prevents future authorised gateway releases
  but cannot erase previously downloaded copies.
- Revocation confirmed before the final permission check must
  block a prepared response. Races after that check remain
  an explicit system boundary.
- A release receipt provides evidence of a gateway release
  attempt, not proof of human viewing or subsequent data use.
- Research compensation uses test credits without monetary value.
- Regulatory compliance certification and production medical
  use are outside the prototype scope.

## 6. References

- [CareConsent Project Proposal](../proposal/CareConsent_Patient-Controlled_Health_Data_and_Aud_proposal.json)
  - System Specification
  - Goals and Objectives
  - User Stories S1-S12
  - Acceptance Tests
  - Definition of Done
  - Blockchain Design
  - Security Model
  - Scope and Exclusions

- [CareConsent Project README](../README.md)
- [CareConsent User Personas](user-personas.md)

## 7. Document Status

This document establishes the initial requirements baseline
for the CareConsent semester prototype.

Requirements are derived from the submitted project proposal.
Implementation status, acceptance results and stakeholder
validation findings will be documented separately.

Changes to the agreed project scope require team coordination
and corresponding proposal updates.
