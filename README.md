# CareConsent
### Patient-Controlled Health Data and Auditable Sharing

CareConsent is a proposed health-data sharing application that will allow patients to manage selected health records and control access by clinicians and researchers. The project combines semantic technologies for consistent data representation and querying with blockchain-based consent records and encrypted off-chain storage.

## Project Status

The project is currently in the **proposal and planning stage**. Implementation has not started.

- **Course:** SEN0401 — Special Topics: Blockchain
- **Semester:** 2026–2027 Fall

## Planned Features

- **Structured health records:** Represent conditions, medication use, allergies and observations using FHIR R4 and RDF.
- **Encrypted storage:** Store encrypted record versions on private IPFS nodes and register their integrity commitments on a local blockchain.
- **Patient-controlled consent:** Grant a named recipient access to selected record versions for a stated purpose and limited period.
- **Clinical queries:** Use predefined SPARQL queries to answer questions such as which antibiotics a patient used during the previous twelve months.
- **Access history:** Let patients inspect gateway release receipts and verify their corresponding blockchain commitments.
- **Research sharing:** Require separate patient approval for research exports and demonstrate compensation using test credits.

## Planned Technology Stack

| Area | Technologies |
|---|---|
| Frontend | React, TypeScript |
| Backend | Java, Spring Boot |
| Semantic model and queries | FHIR R4, RDF/RDFS, OWL, SPARQL, SHACL, Apache Jena |
| Provenance | PROV-O |
| Smart contracts | Solidity, Foundry, Anvil |
| Encrypted storage | IPFS, AES-256-GCM |

## Team and Responsibilities

| Member | Main Responsibilities | Planned Share |
|---|---|---|
| Bahattin Baran Serin | Team coordination, consent contracts and access control | 20% |
| Elif Naz Akdora | FHIR imports, RDF mapping, ontology and requirements documentation | 20% |
| Ayset Mammadova | Clinical queries, acceptance testing and quality assurance | 20% |
| Enes Malik Çolak | Encrypted storage, IPFS integration, architecture and release management | 20% |
| Hasan Samet Yurtbilir | User interfaces, access-history dashboard and research-sharing workflow | 20% |

## Prototype Scope

The prototype will use synthetic health records, private IPFS nodes and a local Ethereum-compatible development network. Research compensation will use valueless test credits.

Revoking consent will prevent future releases through the application. Previously downloaded copies cannot be recalled. Blockchain commitments will provide evidence of registered versions and gateway release attempts, rather than proof of medical accuracy or subsequent human viewing.

## Planned Validation

Evaluation will cover record validation, encryption and integrity checks, consent expiry and revocation, query accuracy, access isolation and duplicate-settlement prevention.

Setup instructions, implementation details and actual evaluation results will be added as development progresses.
