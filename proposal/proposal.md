# CareConsent: Patient-Controlled Health Data and Auditable Sharing

SEN0401 Special Topics: Blockchain · 2026-2027 Fall · Proposal · Method: BRSF software-development profile · Self-assessed grade 91/100

## Team, roles and work distribution

| Member | Student number | E-mail | Administrative roles | Development roles | Planned share |
| --- | --- | --- | --- | --- | --- |
| Bahattin Baran Serin | 2300006459 | 2300006459@stu.iku.edu.tr | Team lead, Process facilitator | Smart-contract developer, Back-end developer | 20% |
| Elif Naz Akdora | 2300003761 | 2300003761@stu.iku.edu.tr | Customer liaison, Documentation lead | Knowledge engineer, Data engineer, Requirements analyst | 20% |
| Ayset Mammadova | 2300003102 | 2300003102@stu.iku.edu.tr | Quality lead, Work-log steward | Back-end developer, Test engineer | 20% |
| Enes Malik Çolak | 2200005577 | 2200005577@stu.iku.edu.tr | Repository and release manager | Back-end developer, Architect, Release and operations | 20% |
| Hasan Samet Yurtbilir | 2100004509 | 2100004509@stu.iku.edu.tr |  | Front-end developer, Interaction and game designer, Smart-contract developer | 20% |

### Modules and features

| Module or feature | Kind | What it does | Delivers epic | Responsible member | Second member |
| --- | --- | --- | --- | --- | --- |
| Health record import and semantic model | Module | Validate synthetic FHIR R4 resources, map them to RDF, apply project SHACL constraints and maintain an encrypted, versioned record manifest. | Import and model chronic-care records | Elif Naz Akdora · 2300003761 | Ayset Mammadova · 2300003102 |
| Encrypted storage and record verification | Module | Encrypt each record version with AES-256-GCM, pin ciphertext on a private IPFS network, protect keys off chain and compare retrieved bytes with the registered digest. | Protect and verify stored record versions | Enes Malik Çolak · 2200005577 | Bahattin Baran Serin · 2300006459 |
| Consent contracts and access gateway | Module | Register patient-controlled grants for a recipient, purpose, selected record versions and expiry; reject access without a currently valid grant. | Enforce patient-controlled sharing permissions | Bahattin Baran Serin · 2300006459 | Enes Malik Çolak · 2200005577 |
| Clinical query workspace | Module | Run approved SPARQL templates on a temporary graph containing only the consenting patient's selected resources and show the supporting record versions. | Answer bounded clinical-history questions | Ayset Mammadova · 2300003102 | Elif Naz Akdora · 2300003761 |
| Patient dashboard and access history | Module | Show records, grants, expiry dates and gateway release receipts; reconcile private audit details with blockchain event commitments. | Explain and verify the patient's sharing history | Hasan Samet Yurtbilir · 2100004509 | Ayset Mammadova · 2300003102 |
| Research sharing and test-credit settlement | Feature | Let a patient separately approve a limited research export and receive one simulated credit payment per approved release, with duplicate settlement prevented. | Demonstrate compensated research sharing within the agreed scope | Hasan Samet Yurtbilir · 2100004509 | Bahattin Baran Serin · 2300006459 |

### Process leads

- Mission analysis: Bahattin Baran Serin
- Stakeholder needs and requirements: Elif Naz Akdora
- System/software requirements definition: Elif Naz Akdora
- Architecture definition: Enes Malik Çolak
- Design definition: Hasan Samet Yurtbilir
- System analysis: Elif Naz Akdora
- Implementation: Bahattin Baran Serin
- Integration: Enes Malik Çolak
- Verification: Ayset Mammadova
- Transition: Enes Malik Çolak
- Validation: Hasan Samet Yurtbilir
- Operation: Enes Malik Çolak
- Maintenance: Ayset Mammadova
- Disposal: Enes Malik Çolak

### Work log

0 entries; chain intact; head fingerprint none.

## 1. Mission

### Customer

Not yet written.

### End users

| User group (short name) | Who exactly | What they do with the system | How often | Device or channel |
| --- | --- | --- | --- | --- |
| Patients | Adults managing a chronic condition who need to share medication, allergy and symptom histories with more than one care provider; represented by synthetic profiles in the prototype. | Review their records, choose which versions to share, approve a named recipient for a limited period, revoke access and inspect the release history. | Weekly | Responsive web application on a smartphone or laptop with a development wallet. |
| Clinicians | Doctors reviewing the longitudinal history of a patient who has explicitly granted them access; represented by separate clinician accounts during testing. | Request access, inspect permitted records and answer bounded questions about medication use, allergies and recorded observations. | Daily | Laptop or desktop browser through the authenticated clinical workspace. |
| Researchers | Research staff requesting a specific dataset for a stated study purpose, with each patient's separate approval; represented by test accounts in the demonstration. | State the research purpose and requested fields, submit an access request, obtain an approved export and inspect the corresponding test-credit receipt. | Occasionally | Desktop browser through the research request screen. |

### Problem

Patients managing a chronic condition may need to assemble medication lists, allergy information and observations from several providers before an appointment. A downloaded report can be forwarded, but it gives the patient little visibility into subsequent access and usually does not express a recipient-specific expiry date. In the United States, the 2024 HINTS survey reported that 59% of individuals had multiple online medical records or patient portals, compared with 50% in 2022 [1]. This is evidence of fragmented access in that population; it is not a measurement of Turkish patients or the project's eventual customer. For a clinician, inconsistent coding and separate documents also make a question such as which antibiotics a patient used in the previous twelve months harder to answer consistently. Research sharing introduces a separate decision: the patient needs to understand the requested data, purpose, duration and any compensation before agreeing. The project will investigate these problems through a bounded prototype and synthetic records. Local task frequency, time spent collecting records and customer priorities still require direct stakeholder validation; no interviews or measured time savings are claimed.

### Mission statement

CareConsent will give Patients a practical way to manage selected health records and decide who may access them, for which purpose and for how long. Clinicians will use consistent, permission-filtered queries to review medication, allergy and observation histories. Encrypted off-chain storage will protect record contents, while smart contracts will register consent changes and commitments to release receipts. A separate research-sharing flow will demonstrate patient approval and compensation using test credits. The semester prototype will use synthetic data and make its trust assumptions and access limits explicit.

Origin: Derived

### Outcome

A patient will be able to share selected record versions with a named clinician until a chosen expiry time, withdraw future access and check recorded gateway releases. An authorised clinician will obtain a reproducible medication-history answer with supporting records. A separately approved research export will produce a traceable test-credit payment.

## 2. Scope

### Areas

| Area | Where it lives | How big it is today |
| --- | --- | --- |
| Health data and semantic model | FHIR import service, RDF mapping, terminology catalogue and validation rules. | No implementation yet; planned evaluation uses 50 synthetic patients and 1,000 clinical resources spanning 24 months. |
| Encrypted storage and integrity | Private IPFS nodes, off-chain key service and record-version registry contract. | No stored prototype records yet; one encrypted object and one integrity commitment per accepted resource version. |
| Consent and access enforcement | Consent smart contract, authenticated access gateway and role-specific browser screens. | No implemented grants yet; three user roles, two declared purposes and a planned matrix of at least 20 access-control cases. |
| Clinical queries and patient audit | Temporary Jena datasets, predefined SPARQL templates and patient access-history dashboard. | No query or audit results yet; five query templates, ten labelled query fixtures and release-to-event reconciliation are planned. |
| Research sharing and evaluation | Research request screen, test-credit contract, integration checks and reproducible demonstration package. | No research exports or payments yet; one-patient exports and at least ten settlement cases are planned. |

### Deliverables

| Deliverable | Area | Layer | Kind |
| --- | --- | --- | --- |
| Synthetic FHIR R4 dataset, documented RDF mapping, small project ontology, terminology catalogue and SHACL shapes with valid and invalid fixtures. | Health data and semantic model | Product layer | Functional |
| AES-256-GCM storage adapter, private IPFS deployment and Solidity registry linking opaque record-version identifiers to ciphertext digests. | Encrypted storage and integrity | Product layer | Functional |
| Storage checks demonstrating authenticated decryption, tamper rejection and absence of plaintext health fields in blockchain transactions and application logs. | Encrypted storage and integrity | Product layer | Non-functional |
| Patient-controlled consent contract and access gateway supporting selected versions, named recipients, purpose, expiry and revocation. | Consent and access enforcement | Product layer | Functional |
| Five SPARQL query templates, clinician results with record provenance, and a patient dashboard reconciling gateway release receipts with blockchain commitments. | Clinical queries and patient audit | Product layer | Functional |
| Separately approved research export with a fixed test-credit fee, patient credit balance and duplicate-settlement protection. | Research sharing and evaluation | Product layer | Functional |
| Versioned source, deployment instructions, automated acceptance checks, proposed stakeholder evaluation script and a final demonstration using synthetic data. | Research sharing and evaluation | Work layer | Functional |

### Exclusions

| Left out | Why |
| --- | --- |
| Live hospital, e-Nabız, insurer and wearable integrations. | External credentials, institutional agreements and production interfaces are not available; documented FHIR fixtures provide a controlled input boundary. |
| Real patient records, clinical trials and deployment for medical decisions. | The semester deliverable is a technical prototype using synthetic data; clinical safety and institutional approval are outside the work plan. |
| Diagnosis, treatment recommendations and automatic allergy or drug-interaction advice. | The system retrieves recorded information and does not establish clinical truth or prescribe care. |
| Public-chain production deployment, real-money payments and a commercial health-data marketplace. | The research compensation mechanism will be evaluated with valueless credits on a local development chain. |
| Guaranteed deletion of every IPFS copy or revocation of data already downloaded. | The gateway can stop future authorised releases, but cannot erase copies retained by recipients or unrelated storage nodes. |
| General natural-language question answering and unrestricted public SPARQL endpoints. | Five reviewed query templates provide a testable scope and reduce disclosure and query-injection risks. |
| Separate athlete application, production wallet recovery and a complete SNOMED CT distribution. | The first release focuses on chronic-care sharing. Terminology use will be limited to an authorised subset if access is available, with an explicitly labelled local demo catalogue otherwise. |

### Domain entities

| Entity | What it is | Created? | Used? | Retired? |
| --- | --- | --- | --- | --- |
| PatientProfile | A synthetic patient identifier with ownership links to record versions and grants; it contains no real person's identity. | Created — yes | Used — yes | Retired — yes |
| HealthRecordVersion | An immutable version of a Condition, MedicationStatement, AllergyIntolerance or Observation resource, with source, timestamp, encrypted object reference and integrity commitment. | Created — yes | Used — yes | Retired — yes |
| TerminologyConcept | A versioned concept used to code a condition, observation or medication class; standard concepts and local demonstration concepts remain distinguishable. | Created — yes | Used — yes | Retired — no |
| AccessRequest | A recipient's request naming patient, selected record versions, declared purpose and requested period, optionally including a research fee. | Created — yes | Used — yes | Retired — yes |
| ConsentGrant | A patient's authorisation for one recipient and purpose over an explicit immutable set of record versions, ending through expiry or revocation. | Created — yes | Used — yes | Retired — yes |
| ReleaseReceipt | An encrypted gateway audit record for an authorised release, including recipient, grant, versions, outcome and time; its commitment is anchored on chain. | Created — yes | Used — yes | Retired — no |
| ResearchSettlement | A one-time transfer of valueless development credits from a funded research request to the patient after the gateway confirms an approved export. | Created — yes | Used — yes | Retired — yes |

### Project kinds

Knowledge-graph application › Graph-backed web application; Provenance and trust › Blockchain-anchored provenance. Stack layers they need: Data model, Query, Storage and serving, Identifiers and publishing, Provenance and metadata.

### Semantic technologies, by stack layer

- Data model: RDF directed edge-labelled graph model
- Identifiers and publishing: Stable IRI and negotiation practice
- Ontologies: OWL 2 Web Ontology Language
- Provenance and metadata: PROV-O provenance ontology
- Query: SPARQL 1.1 and 1.2
- Serialisation: RDF directed edge-labelled graph model
- Storage and serving: Apache Jena and Fuseki
- Validation: SHACL shapes
- Vocabularies and taxonomies: RDF Schema

FHIR R4 provides the resource structure for conditions, medication statements, allergies and observations; its RDF representation bridges those resources to graph processing [2]. RDFDataModel represents links between patients, records and grants. RDFSchemaLanguage and a small OWL2Language ontology define project classes and relationships; they do not turn recorded statements into verified medical facts. A licensed SNOMED CT subset may supply selected clinical codes, subject to confirmed access [9]; the reproducible fallback is a clearly labelled local demonstration catalogue. SPARQLFamily is used at the SPARQL 1.1 level for five parameter-bound templates [5]. SHACLCore checks project-specific cardinalities, date ranges and required links, in addition to FHIR resource validation [6]. The ApacheJenaFuseki catalogue entry is used for Apache Jena's embedded, transactional in-memory dataset and SHACL support; no public Fuseki endpoint is planned [10]. PROVOStandard links query results and exports to their source versions and producing activities [7]. CoolURIPractice gives internal resources stable opaque IRIs without publishing patient records. React and TypeScript will provide the screens, a Java Spring Boot service will coordinate validation and access, and Solidity contracts tested with Foundry will run on Anvil. AES-256-GCM ciphertext will be stored on private IPFS nodes; keys and sensitive metadata will remain off chain [4].

## 3. Goals

| Goal | Facing | Covers area | Why this goal |
| --- | --- | --- | --- |
| Represent the selected chronic-care records consistently and reject malformed imports. | Scope-facing | Health data and semantic model | Clinical queries need explicit coding, usable dates and reliable links before sharing can be assessed. |
| Store encrypted record versions and detect changes before any decrypted content is returned. | Scope-facing | Encrypted storage and integrity | A blockchain digest is useful only when the actual returned object is checked against it. |
| Give patients effective control over future gateway access by recipient, purpose, selected versions and time. | Mission-facing | Consent and access enforcement | A consent screen must correspond to an enforced access decision, including refusal paths. |
| Provide reproducible clinical-history answers and patient-visible evidence of gateway releases. | Mission-facing | Clinical queries and patient audit | The patient and clinician need useful records and an understandable history of the system's sharing actions. |
| Demonstrate a separately consented research export with one traceable patient test-credit payment. | Scope-facing | Research sharing and evaluation | The proposed patient compensation model needs an observable, bounded workflow before commercial assumptions are considered. |
| Keep the implementation and evaluation inside the synthetic-data, local-network and predefined-query boundaries. | Containment-facing | Research sharing and evaluation | The semester should deliver the agreed sharing workflow without expanding into hospital integration, clinical decision support or a marketplace. |

### Specification

The prototype shall support Patients, Clinicians and Researchers as separate authenticated roles. A patient may import synthetic FHIR R4 records, view validation errors and register an accepted encrypted version. Each new version shall receive a fresh encryption key and nonce; its digest shall cover the exact encrypted envelope bytes, avoiding dependence on RDF serialisation order. A patient shall approve a recipient, declared purpose, explicit record-version list and expiry. The contract shall bind that immutable list through a scope commitment, and the gateway shall verify the list against it. Requests shall be denied if the grant is absent, revoked, expired, for another recipient or purpose, or excludes any requested version. The server shall use a short-lived wallet-signature challenge bound to the session and chain. An authorised query shall decrypt only permitted objects into a temporary graph, run a reviewed template and return only its permitted projection. Consent shall be checked again immediately before release. A release receipt commitment shall be confirmed on chain before the response is sent; the receipt describes an authorised release attempt rather than proof that a human read it. If the chain, storage, integrity check or audit anchoring is unavailable, release shall fail closed. A research export shall require its own grant and funded test-credit request. Settlement shall be idempotent and shall rely on the explicitly trusted gateway's release attestation. No private key, clinical text, raw CID or plaintext patient identifier shall be placed on chain. The gateway and key service remain trusted components capable of processing plaintext; this is not a claim of trustless or end-to-end private computation.

### Test scenarios

| Kind | Scenario (Given / When / Then) |
| --- | --- |
| Nominal | Given a patient has granted a clinician access to selected medication records for treatment until tomorrow, when that clinician runs the antibiotics template within the permitted interval, then only matching permitted records are returned with source versions and a confirmed release receipt commitment. |
| Rejection | Given the patient has revoked a clinician's grant, when the clinician repeats a previously successful request, then the gateway refuses it before decryption or result release and exposes no clinical fields. |
| Boundary | Given a grant expires at time T according to the latest confirmed local-chain block, when access is evaluated at T minus one second it may pass, and when evaluated at T it must fail; authorisation requires current time strictly less than expiry. |
| Rejection | Given a researcher holds a treatment-only grant or asks for an unselected allergy record, when an export is requested, then the purpose or scope mismatch is rejected and no credit settlement occurs. |
| Rejection | Given an encrypted object differs from its anchored digest or fails authenticated decryption, when a permitted recipient requests it, then the object is rejected without returning any partial plaintext. |
| Absent | Given a valid grant covers a patient with no antibiotic records in the requested interval, when the template runs, then the workspace displays an explicit no-matching-records result, distinct from denied access or missing storage. |
| Rejection | Given the chain cannot confirm a release receipt, when an otherwise authorised response is prepared, then the gateway returns a service-unavailable result without releasing clinical content or settling research credits. |

### Use cases

Patients: import records, review validation errors, inspect versions, approve or refuse requests, revoke future access, inspect release receipts and approve research compensation terms. Clinicians: request treatment access, choose a permitted patient and interval, run one of five clinical templates and inspect the supporting resource versions. Researchers: request a specific one-patient export for a stated study purpose, fund the test-credit request and obtain the separately approved export. The gateway verifies identity, consent, scope, time and ciphertext integrity before each release. Neither a role label nor possession of an IPFS reference is sufficient authorisation.

## 4. Objectives

| Objective | Goal | Measured by | How exactly it is measured | Now | Target | Direction |
| --- | --- | --- | --- | --- | --- | --- |
| Validate and map the planned synthetic evaluation dataset. | Represent the selected chronic-care records consistently and reject malformed imports. | Counted | A reproducible validation run counts accepted resources, linked patient profiles, mapped resource types and rejected negative fixtures. Expected resource identifiers are compared before and after mapping. | 0 imported or mapped prototype records; no validation run has been performed. | 50 synthetic patient profiles and 1,000 valid clinical resources mapped; all 20 deliberately malformed fixtures rejected with a specific reason. | Increase |
| Verify every accepted encrypted version and reject tampered objects. | Store encrypted record versions and detect changes before any decrypted content is returned. | Derived | For all 1,000 resource versions, compare SHA-256 of the retrieved encrypted envelope with its registry commitment and attempt authenticated decryption. Repeat with 20 mutated objects and incorrect keys. | 0 verified prototype versions; integrity and encryption checks are not implemented. | 1,000 successful round trips for valid versions, 20 of 20 tampered or wrong-key cases rejected, and no plaintext clinical fields found in the inspected chain and application logs. | Increase |
| Enforce the complete consent decision matrix. | Give patients effective control over future gateway access by recipient, purpose, selected versions and time. | Derived | Execute at least 20 cases spanning valid grants, wrong recipient, wrong purpose, missing grant, excluded version, expiry boundary, revocation, replay and concurrent revoke-before-release. Inspect responses and key-service calls. | 0 implemented or executed access-control cases. | 100% of specified denial cases return no clinical result or decryption key, and every specified valid case succeeds when dependencies are available. | Increase |
| Return correct permission-filtered answers and reconcile release receipts. | Provide reproducible clinical-history answers and patient-visible evidence of gateway releases. | Derived | Compare five templates over ten manually labelled synthetic query fixtures with expected record identifiers; join all successful gateway release attempts to event commitments. Measure 100 authorised local requests, excluding initial import, on a documented machine. | 0 verified query fixtures or reconciled release receipts; response latency is not yet measured. | 10 of 10 fixtures match exactly, no cross-patient or out-of-scope result appears, 100% of successful release attempts have a matching event commitment, and local p95 response time is at most 3 seconds. | Increase |
| Settle approved research sharing once per release identifier. | Demonstrate a separately consented research export with one traceable patient test-credit payment. | Derived | Execute ten settlement cases covering a funded approved export, refusal, expiry, insufficient funds, an untrusted attester and duplicate retries. Compare the patient's credit balance with settlement events. | 0 approved exports and 0 settlement cases implemented or executed. | All ten cases match their expected outcomes; an approved export credits its stated fee exactly once, while denied and unfunded requests transfer nothing. | Increase |
| Deliver a reproducible prototype without crossing the agreed scope boundaries. | Keep the implementation and evaluation inside the synthetic-data, local-network and predefined-query boundaries. | Counted | Review every merged feature against A1-A5 and E1-E6; inspect fixtures, configuration and the demonstration script for real records, public deployment, real-money transfers and unplanned integrations. | 0 implementation artefacts reviewed; the project is at proposal stage. | Every merged feature traces to a planned epic, all acceptance fixtures are synthetic, and zero excluded integrations or real-money features are required by the release. | Hold |

### Activity model

Start -> authenticate the account with a fresh wallet challenge -> choose import, access request or patient review. Import branch: validate FHIR and project shapes; on failure show field-level errors and stop; on success encrypt a new version, pin ciphertext, confirm the digest registration and show it in the manifest. Sharing branch: a recipient submits scope, purpose and duration; the patient refuses or signs a grant. Access branch: check confirmed grant state and scope; on failure return denial; on success fetch and verify ciphertext, decrypt into a temporary dataset and run the selected query or export projection. Recheck consent immediately before release; if it changed, discard the prepared response. Otherwise confirm a receipt commitment and send the result. For a funded research export, record one settlement using the release identifier. Close the temporary dataset after either success or failure. Expiry and revocation block later releases, while earlier receipts remain visible.

### Sequence model

Patient browser -> gateway: signed challenge and synthetic FHIR import. Gateway -> validator: resource and shape checks. Gateway -> key service: generate and wrap a per-version key. Gateway -> private IPFS: encrypted envelope; IPFS -> gateway: CID. Patient browser -> registry contract: sign registration of an opaque version identifier and ciphertext digest. Clinician browser -> gateway: request named versions for treatment. Patient browser -> consent contract: sign the recipient, scope commitment, purpose and expiry. Clinician browser -> gateway: run a query template with a grant identifier. Gateway -> contract: read current confirmed grant. Gateway -> IPFS and key service: fetch verified ciphertext and unwrap authorised keys. Gateway -> embedded Jena: build the scoped temporary dataset and execute the bound template. Gateway -> contract: recheck permission and anchor a release receipt commitment. After confirmation, gateway -> clinician: projected result and receipt reference. Gateway closes the dataset. The research variant adds an approved funded request and an idempotent gateway-attested settlement transaction.

## 5. Backlog

Kind of development: Initial development

### Epics

| Epic | Pursues objective |
| --- | --- |
| Import and model chronic-care records | Validate and map the planned synthetic evaluation dataset. |
| Protect and verify stored record versions | Verify every accepted encrypted version and reject tampered objects. |
| Enforce patient-controlled sharing permissions | Enforce the complete consent decision matrix. |
| Answer bounded clinical-history questions | Return correct permission-filtered answers and reconcile release receipts. |
| Explain and verify the patient's sharing history | Return correct permission-filtered answers and reconcile release receipts. |
| Demonstrate compensated research sharing within the agreed scope | Settle approved research sharing once per release identifier. |

### Stories

| Epic | As a | I want | So that | Acceptance (Given / When / Then) | Category | Design concern | Value 1–10 | Time 1–10 | Risk 1–10 | Size 1–10 | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Import and model chronic-care records | Patients (end user) | import a structured medication, allergy, condition or observation record | my selected health history can be interpreted consistently | Given a supported synthetic FHIR record with a valid patient reference, when I import it, then the system accepts it and creates a traceable RDF representation; an invalid record instead returns a field-specific error without registration. | New capability | Data | 9 | 8 | 8 | 5 | 5 |
| Protect and verify stored record versions | Patients (end user) | store an encrypted and verifiable version of each accepted record | storage nodes cannot read its clinical contents and later changes can be detected | Given an accepted record, when it is stored, then only an authenticated encrypted envelope is pinned and its digest is registered; a changed envelope or wrong key prevents all plaintext release. | New capability | Architecture | 10 | 9 | 10 | 7 | 4.1 |
| Enforce patient-controlled sharing permissions | Patients (end user) | grant a named clinician access to selected versions until a chosen expiry | sharing is limited to the appointment's needs | Given a request for selected medication versions, when I sign a treatment grant, then only that recipient, purpose and immutable version list is authorised before expiry; a different recipient or additional version is denied. | New capability | Security | 10 | 10 | 10 | 6 | 5 |
| Enforce patient-controlled sharing permissions | Patients (end user) | revoke an existing grant | future releases through the application stop | Given a currently valid grant, when my revocation transaction is confirmed, then every subsequent release check denies that grant, including a prepared response awaiting its final check; the interface explains that earlier downloaded copies remain outside this control. | New capability | Security | 10 | 9 | 10 | 5 | 5.8 |
| Enforce patient-controlled sharing permissions | Clinicians (end user) | see whether my requested access is pending, active, refused, expired or revoked | I understand whether a patient-authorised review is available | Given I have submitted a request, when I open its status, then the application shows the current request and grant state without exposing any health fields before permission is active. | New capability | Interaction | 7 | 6 | 7 | 3 | 6.7 |
| Answer bounded clinical-history questions | Clinicians (end user) | list recorded antibiotic use overlapping the previous twelve months | I can review the permitted medication history before consultation | Given a valid medication grant and a fixed evaluation interval, when I run the antibiotic template, then it returns exactly the permitted matching MedicationStatement versions, excludes entered-in-error records and includes their source dates and versions; a prescription alone is not presented as confirmed use. | New capability | Interface | 9 | 7 | 8 | 5 | 4.8 |
| Answer bounded clinical-history questions | Clinicians (end user) | review active recorded conditions, active allergies and dated symptom or exercise observations | I can inspect a coherent permitted history without opening separate reports | Given grants covering the relevant record types, when I run each of the four remaining templates, then the results match the labelled fixtures and contain only permitted patient records; an empty match is distinguished from denial or a missing object. | New capability | Data | 8 | 6 | 7 | 5 | 4.2 |
| Explain and verify the patient's sharing history | Patients (end user) | inspect who received records through the gateway and when | I can review the application's sharing actions | Given an authorised release attempt, when I open its history entry, then I see the recipient, purpose, versions, time and a receipt commitment matching a confirmed chain event; the entry does not claim to prove later human viewing or onward sharing. | New capability | User interface | 9 | 7 | 8 | 5 | 4.8 |
| Demonstrate compensated research sharing within the agreed scope | Researchers (end user) | request a narrow dataset for a stated study purpose and test-credit fee | the patient can make a separate informed sharing decision | Given no research grant exists, when I request an export with selected versions, requested fields, expiry and fee, then the patient sees those terms and can approve or refuse; a treatment grant cannot authorise this export. | New capability | User interface | 7 | 5 | 8 | 5 | 4 |
| Demonstrate compensated research sharing within the agreed scope | Patients (end user) | receive the agreed test-credit fee once for an approved research release | the proposed compensation flow is transparent and checkable | Given an approved research grant and sufficient funded test credits, when the trusted gateway attests an authorised export release, then the contract credits the stated fee to my development account once and emits a settlement event; repeating the same release identifier cannot pay again. | New capability | Security | 7 | 4 | 8 | 6 | 3.2 |
| Protect and verify stored record versions | Patients (end user) | create a corrected version without silently changing earlier records | the history remains traceable and old permissions do not silently expand | Given a registered version and a grant covering it, when I import a correction, then a new version with a fresh key and digest is created; the earlier commitment remains, and sharing the correction requires explicit inclusion in a new grant. | New capability | Data | 8 | 6 | 9 | 4 | 5.8 |
| Explain and verify the patient's sharing history | Patients (end user) | receive a clear failure message when a safe release cannot be completed | I can distinguish a system problem from an empty medical history | Given storage is missing or the chain cannot confirm the receipt, when a recipient asks for my records, then the gateway releases no clinical content, returns a distinct unavailable result and leaves the request eligible for a safe retry. | New capability | Interface | 8 | 7 | 9 | 4 | 6 |

### Definition of done

| Criterion | How it is checked |
| --- | --- |
| The story meets its specified nominal and refusal outcomes. | Run its linked acceptance cases against a clean synthetic fixture set; attach actual results and evidence at final submission. |
| Authorisation is enforced at the gateway and contract boundary. | Review recipient, purpose, version list, time and revocation checks; denial cases must expose no health result or key. |
| Stored and returned versions are traceable and verifiable. | Check encrypted-envelope digest verification and the link from result to source version and confirmed receipt event. |
| Sensitive content stays out of public interfaces and routine logs. | Inspect transaction calldata, events, browser responses, application logs and storage objects using planted synthetic identifiers and clinical strings. |
| The work is reproducible and within scope. | A second team member can follow the setup instructions, replay the synthetic demonstration and identify the epic and module for the change. |
| The feature has a named owner, peer review and usable screens. | Before implementation is accepted, assign actual team members, review the change and walk through success, empty, denied and unavailable states. |

### Class model

PatientProfile(patientId, ownerAccount) owns 0..* HealthRecordVersion(versionId, resourceType, recordedAt, status, ciphertextDigest, replacesVersion). A version belongs to exactly one patient. Its protected StorageManifest entry holds CID, wrappedKeyRef and the RDF mapping version; these fields are not public contract data. TerminologyConcept(system, code, label, catalogueVersion) codes record properties. AccessRequest(requestId, requester, purpose, requestedVersionList, requestedUntil, fee) may produce one ConsentGrant(grantId, owner, grantee, purposeCode, scopeCommitment, expiresAt, revoked). The immutable encrypted scope manifest resolves the commitment to versions. ReleaseReceipt(releaseId, grantId, requester, versions, releasedAt, outcome, eventTx) describes a gateway release attempt. PROV-O links a query or export activity to its source versions and output. ResearchSettlement(releaseId, fee, patientAccount, settled) references one approved research release. Superseded records remain historically identifiable; retiring a record removes it from new selection without rewriting its earlier chain commitment.

### Test cases

| For story | Test case | Test data |
| --- | --- | --- |
| import a structured medication, allergy, condition or observation record | Accept supported records and reject malformed imports before storage registration. | Valid synthetic Condition, MedicationStatement, AllergyIntolerance and Observation resources; 20 negative fixtures with missing patient links, invalid types, unsupported modifiers or inconsistent dates. |
| store an encrypted and verifiable version of each accepted record | Round-trip valid ciphertext and reject tampering or wrong-key decryption. | 1,000 generated clinical resources; 20 altered envelopes or incorrect keys; two encryptions of the same resource to check fresh nonce/key use. |
| grant a named clinician access to selected versions until a chosen expiry | Enforce recipient, purpose, scope and expiry on direct API calls as well as UI requests. | Patient P01, two clinician accounts, one researcher, selected medication versions and an excluded allergy version; evaluate at expiry minus one second and exactly expiry. |
| revoke an existing grant | Reject new access and a prepared response after confirmed revocation. | One active grant, a confirmed revoke transaction and a controlled pause before the gateway's final permission check; replay the prior request after revocation. |
| see whether my requested access is pending, active, refused, expired or revoked | Show each request state without disclosing clinical payloads. | Pending, refused, active, expired and revoked fixtures; inspect both rendered status and network responses. |
| list recorded antibiotic use overlapping the previous twelve months | Return the exact allowed antibiotic record identifiers at temporal boundaries. | Evaluation time 2026-12-01T00:00:00Z and interval [2025-12-01T00:00:00Z, 2026-12-01T00:00:00Z); include overlapping use periods, non-antibiotics, entered-in-error statements, excluded versions and another patient. |
| review active recorded conditions, active allergies and dated symptom or exercise observations | Check the four remaining templates against labelled results and handle an empty permitted graph. | Active and inactive conditions and allergies, symptom observations, exercise observations, different units, missing optional fields and a patient with no matching records; ten query fixtures in total across S6-S7. |
| inspect who received records through the gateway and when | Reconcile private receipt details with confirmed event commitments and detect receipt modification. | Successful releases for two recipients, one altered receipt and one interrupted response after anchoring; label the latter as an attempted release with delivery unconfirmed. |
| request a narrow dataset for a stated study purpose and test-credit fee | Require separate research approval and show requested fields, purpose, duration and fee. | A valid treatment grant, no research grant, a pending research request and approved/refused variants; selected direct-identifier fields must be excluded from the research projection. |
| receive the agreed test-credit fee once for an approved research release | Pay the approved fee once and reject unfunded, unauthorised and repeated settlements. | Ten settlement fixtures using valueless local credits, including sufficient funds, insufficient funds, wrong attester, expired grant, missing release attestation and duplicate release identifiers. |
| create a corrected version without silently changing earlier records | Keep old commitments intact and require fresh consent for a corrected version. | Two versions of one medication statement with distinct keys, nonces, digests and CIDs; an existing grant names only the first version. |
| receive a clear failure message when a safe release cannot be completed | Fail closed on storage, key-service or chain failure and retry safely. | Unavailable IPFS object, failed key unwrap, rejected audit transaction, stale chain connection and a repeated request with the same release identifier. |

### Architecture — Component diagram

Component model: [React browser] -> [Spring Boot access gateway] -> [FHIR validator and RDF mapper], [embedded Jena dataset], [private IPFS adapter], [key service] and [EVM contract adapter]. The patient wallet signs registrations and grants; the gateway cannot create patient consent. Solidity contracts hold version commitments, grant state and test-credit settlements. IPFS holds encrypted envelopes. The key service and gateway form a trusted plaintext-processing boundary. Query datasets exist only for an authorised operation and are closed afterwards; no persistent plaintext clinical triplestore is planned.

### Data — Class diagram

Design class model: PatientProfile 1 -> many HealthRecordVersion; HealthRecordVersion many -> many TerminologyConcept; AccessRequest 0..1 -> ConsentGrant; ConsentGrant 1 -> one immutable ScopeManifest containing selected version identifiers; ConsentGrant 1 -> many ReleaseReceipt; ReleaseReceipt 0..1 -> ResearchSettlement. Ciphertext storage, wrapped keys and receipt details are off chain. Opaque identifiers, ciphertext digests, scope commitments, expiry, revocation and settlement identifiers form contract state. Version updates create new objects and never mutate a previously committed version.

### Interaction — Sequence diagram

Sequence model for a clinician request: clinician -> gateway submits selected versions and treatment purpose; gateway -> patient dashboard presents the request; patient -> wallet signs approval; wallet -> consent contract submits the grant; contract confirmation -> dashboard changes status to active. The clinician then requests a template result. The gateway checks consent, prepares the scoped answer, repeats the permission check and confirms an audit commitment before attempting delivery. Refusal, expiry and revocation produce distinct status messages. Research requests follow the same decision path with a separate purpose and explicit fee.

### Interface — Component diagram

Interface component model: browser clients call authenticated endpoints for imports, requests, grants, predefined queries, research exports and audit history. Query input is a template identifier plus validated patient, grant and date parameters; arbitrary SPARQL text, SERVICE federation and update operations are unavailable. The contract adapter provides registerVersion, grantAccess, revokeGrant, recordRelease and settleResearch operations with explicit caller checks. The storage adapter accepts and returns encrypted envelopes only. API results distinguish validation failure, access denial, no match, integrity failure and dependency unavailability without exposing internal key material or unselected resource fields.

### Security — State machine diagram

Grant state machine: Unapproved -> Active only after the owner signs and the transaction is confirmed. Unapproved -> Refused when the patient rejects the request. Active -> Revoked through an owner transaction, or Active -> Expired when confirmed chain time reaches expiresAt. Revoked, Expired and Refused cannot authorise release; a new request requires a new grant. Release state machine: Requested -> Checked -> Prepared -> Rechecked -> ReceiptConfirmed -> ResponseAttempted. Any failed identity, scope, purpose, integrity or dependency check moves to Denied or Unavailable with no content release. A revocation confirmed before the final release check blocks the response; races after that check remain an explicit boundary. Signed challenges use a nonce, domain, chain identifier and short expiry to prevent replay.

### User interface — design model

Storyboard: sign in -> patient record list -> select versions -> review recipient, purpose and expiry -> wallet confirmation -> grant detail with revoke action -> release history. The clinician workspace shows pending permission before enabling its five query templates. Results display the evaluated interval and supporting versions. The research request screen adds the requested projection and test-credit fee, followed by a separate approval page. Empty results, denied access and unavailable services have different messages. The history screen describes gateway release attempts and explains that downloaded copies cannot be recalled. Labels and controls will support keyboard use on laptop and mobile layouts.

## 6. Course-specific

### Blockchain design

The mandatory demonstration will use Solidity contracts on Anvil, an isolated Ethereum-compatible development node operated by the team [8]. This removes faucet and transaction-cost dependencies and supports reproducible expiry and failure tests. Anvil is a development environment, not evidence of decentralised production consensus or resistance to a malicious node operator. The registry will anchor a SHA-256 digest of each exact encrypted envelope and an opaque version identifier. The consent contract will store an owner, recipient, purpose code, immutable version-set commitment, expiry and revocation state; sensitive scope details and raw CIDs remain off chain. The gateway will enforce those decisions before decrypting or returning results, while an allowlisted gateway signer anchors commitments to private release receipts. Record contents and keys are never placed in contract storage. Blockchain is included because a deployed shared ledger can give patients, providers and researchers a common history of consent changes, registered versions and settlement events that one application database administrator cannot silently rewrite. A conventional signed audit database would be simpler if every party accepted one operator; that trade-off will be stated in the evaluation. Neither a digest nor an event proves medical accuracy, hospital deletion, actual human viewing or the absence of onward sharing. A small test-credit ledger will model compensation: the researcher funds a stated fee, the patient approves the research grant, and an authorised gateway attestation permits one settlement for the release identifier. Unused expired requests can refund their funding. The gateway is trusted for release attestation, and credit payment does not prove that an external recipient received or used the data. Contracts will use explicit authorisation checks, replay-resistant identifiers, checked state transitions and idempotent settlement tests. The prototype's benefit will be assessed through these observable workflows rather than claims of full decentralisation or automatic legal compliance.

## Plan and risks

| Date | Deliverable | Lead |
| --- | --- | --- |
| 2026-10-23 | Freeze the synthetic-data scope, confirm stakeholder and team details, assign modules and agree the record, grant and receipt models. | Bahattin Baran Serin |
| 2026-11-06 | Complete FHIR fixtures, RDF mapping, terminology catalogue, SHACL checks and the first encrypted IPFS round trip. | Elif Naz Akdora |
| 2026-11-20 | Integrate record registration, patient-signed grants, expiry, revocation and the access-control matrix on Anvil. | Bahattin Baran Serin |
| 2026-12-04 | Complete the five query templates, scoped temporary datasets, patient dashboard and release-receipt reconciliation. | Ayset Mammadova |
| 2026-12-11 | Complete separate research approvals, funded test-credit settlement and duplicate-payment checks; run the integrated demonstration. | Hasan Samet Yurtbilir |
| 2026-12-18 | Run acceptance, isolation, failure and latency checks; review against the scope; conduct stakeholder walkthroughs if participants have been secured and record actual findings. | Ayset Mammadova |
| 2026-12-22 | Submit the documented release, reproducible synthetic demonstration and actual final-stage evidence; retain the last days for repairs and submission checks. | Enes Malik Çolak |

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| No real commissioning customer or stakeholder participants have been confirmed. | High | High | Secure a reachable patient representative, care unit or research group early; record the actual contact and priorities. If external walkthroughs cannot be arranged, report that limitation and keep technical acceptance separate from user validation. |
| SNOMED CT access or redistribution permission may not be available in time. | Medium | Medium | Confirm the applicable licence and permitted subset before including terminology content. Keep FHIR mappings independent and use a labelled local demo catalogue for the reproducible release if authorisation is unavailable. |
| A compromised gateway or key service could expose plaintext despite blockchain permissions. | Medium | High | Treat those services as explicit trust boundaries, isolate key storage, avoid plaintext persistence and logs, use short-lived processing and check every release. Document that ledger consent cannot constrain a malicious key holder. |
| A stale permission read or revocation race could release prepared data after the patient changes consent. | Medium | High | Use confirmed chain state, recheck immediately before release, refuse stale or unavailable state and exercise a controlled concurrent-revocation test. State the residual race boundary after the final check. |
| IPFS objects may be unavailable, and removing a pin does not erase every retained copy. | Medium | High | Use team-controlled private nodes, pin encrypted objects on two nodes, keep an encrypted backup and test retrieval failure. Avoid deletion guarantees and explain that revocation limits later gateway releases only. |
| Incorrect terminology mapping or date handling may produce misleading query results. | Medium | High | Version the small catalogue, validate UTC intervals and resource status, use manually labelled boundary fixtures and show supporting source records. Do not interpret a prescription as proof of medication use. |
| Contract errors or repeated requests may create duplicate credit payments. | Medium | Medium | Use valueless credits, an explicit funded-request state machine, an allowlisted attester and a unique settled release identifier; test insufficient funds, unauthorised calls and retries. |
| The remaining semester may be too short for broad integrations or polished secondary features. | Medium | High | Freeze the five-template synthetic prototype, complete storage and consent before research settlement, assign an owner and second member for every module and reserve the final days for repairs. |
| A local chain can be reset by its operator, limiting the audit guarantee demonstrated. | Medium | Medium | Publish reproducible chain configuration and saved test receipts, state the local operator assumption and evaluate contract behaviour separately from production ledger governance. |

Repository: https://github.com/baranserin/SpecialTopicsProject_CareConsent — Confirmed on GitHub 2026-10-17 (public, created 2026-10-17)

## References

1. [1] ASTP/ONC. Individuals' Access and Use of Patient Portals and Smartphone Health Apps, 2024. Data Brief No. 77, July 2025; HINTS 7 (2024) and HINTS 6 (2022), findings on multiple portals. https://healthit.gov/data/data-briefs/individuals-access-and-use-patient-portals-and-smartphone-health-apps-2024/ (accessed 17 October 2026).
2. [2] HL7 International. FHIR R4, version 4.0.1: RDF Representation. https://hl7.org/fhir/R4/rdf.html (accessed 17 October 2026).
3. [3] HL7 International. FHIR R4, version 4.0.1: Security and Consent. https://hl7.org/fhir/R4/security.html ; https://hl7.org/fhir/R4/consent.html (accessed 17 October 2026).
4. [4] IPFS Documentation. Privacy and encryption. https://docs.ipfs.tech/concepts/privacy-and-encryption/ (accessed 17 October 2026).
5. [5] W3C. SPARQL 1.1 Query Language. Recommendation, 21 March 2013. https://www.w3.org/TR/sparql11-query/ (accessed 17 October 2026).
6. [6] W3C. Shapes Constraint Language (SHACL). Recommendation, 20 July 2017. https://www.w3.org/TR/shacl/ (accessed 17 October 2026).
7. [7] W3C. PROV-O: The PROV Ontology. Recommendation, 30 April 2013. https://www.w3.org/TR/prov-o/ (accessed 17 October 2026).
8. [8] Foundry Documentation. Anvil: local Ethereum node for development and testing. https://www.getfoundry.sh/anvil/index.html (accessed 17 October 2026).
9. [9] SNOMED International. Vendor Introduction to SNOMED CT: Licensing. https://docs.snomed.org/snomed-ct-practical-guides/vendor-introduction-to-snomed-ct/7-licensing (accessed 17 October 2026).
10. [10] Apache Jena Documentation. In-memory, transactional Dataset; Apache Jena SHACL. https://jena.apache.org/documentation/rdf/datasets.html ; https://jena.apache.org/documentation/shacl/index.html (accessed 17 October 2026).

## Self-assessment

| Part | Weight | Grade | Criteria met |
| --- | --- | --- | --- |
| Team and work | 10% | 76/100 | 10 of 12 |
| Mission | 20% | 67/100 | 5 of 7 |
| Scope | 15% | 100/100 | 8 of 8 |
| Goal | 15% | 100/100 | 7 of 7 |
| Objective | 10% | 100/100 | 3 of 3 |
| Backlog | 20% | 100/100 | 10 of 10 |
| Course-specific | 5% | 100/100 | 1 of 1 |
| Plan and references | 5% | 100/100 | 3 of 3 |
| Overall | 100% | 91/100 |  |

### Member grades (Proposal)

Project grade 92.7 (60%), team grade 76 (20%), individual contribution (20%).

| Member | Student number | Individual | Member grade |
| --- | --- | --- | --- |
| Bahattin Baran Serin | 2300006459 | 22 | 75.2 |
| Elif Naz Akdora | 2300003761 | 22 | 75.2 |
| Ayset Mammadova | 2300003102 | 22 | 75.2 |
| Enes Malik Çolak | 2200005577 | 22 | 75.2 |
| Hasan Samet Yurtbilir | 2100004509 | 22 | 75.2 |

