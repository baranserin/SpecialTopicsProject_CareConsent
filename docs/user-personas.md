# CareConsent - User Personas

## 1. Introduction

CareConsent is a patient-controlled health data sharing prototype
that combines blockchain technology, encrypted storage and
semantic technologies.

This document defines the three primary user personas of the
system: Patient, Clinician and Researcher.

The personas are based on the project proposal and represent
hypothetical users. They have not yet been validated through
direct stakeholder interviews.

## 2. Patient Persona

### Profile

- Persona ID: UP-01
- Role: Patient
- Background: An adult managing a chronic health condition.
- Expected usage: Weekly
- Device: Smartphone or laptop
- Technical knowledge: Basic digital literacy (assumed)

### Goals

- Manage personal health records.
- Share selected record versions with authorised clinicians.
- Control who can access records, for what purpose and for how long.
- Review and revoke existing access permissions.
- Inspect the history of gateway release attempts.
- Approve or refuse separate research sharing requests.

### Challenges

- Health information may be distributed across different providers.
- Limited control over previously shared medical documents.
- Concerns about privacy and unauthorised access.
- Difficulty reviewing how health information has been shared.

### System Needs

- A clear and accessible patient dashboard.
- Secure import and storage of synthetic health records.
- Recipient-specific, purpose-specific and time-limited consent.
- Explicit selection of record versions.
- Consent revocation for future data releases.
- Verifiable release receipts.
- Transparent research approval and test-credit settlement.

### Access Limitations

Patients can manage their own records and consent permissions.
Revocation prevents future releases through the application
but cannot remove copies previously downloaded by recipients.

### Related User Stories

S1, S2, S3, S4, S8, S10, S11, S12.

## 3. Clinician Persona

### Profile

- Persona ID: UP-02
- Role: Clinician
- Background: A doctor reviewing a patient's medical history.
- Expected usage: Daily
- Device: Laptop or desktop computer
- Technical knowledge: Familiar with digital health systems (assumed)

### Goals

- Request access to relevant patient records.
- Review medication, allergy and condition histories.
- Retrieve relevant information through predefined clinical queries.
- Identify the source versions of query results.
- Understand the current status of access permissions.

### Challenges

- Fragmented medical information.
- Inconsistent health data formats.
- Difficulty reviewing longitudinal medication histories.
- Uncertainty about current access permissions.

### System Needs

- An authenticated clinical workspace.
- A clear access request and consent status interface.
- Structured and permission-filtered health information.
- Five predefined clinical query templates.
- Traceable results linked to source record versions.
- Distinct messages for empty, denied and unavailable results.

### Access Limitations

Clinicians can access only the record versions explicitly
authorised by the patient for the approved treatment purpose.

Access must be denied when consent is absent, expired, revoked
or inconsistent with the requested recipient, purpose or scope.

### Related User Stories

S3, S4, S5, S6, S7, S12.

## 4. Researcher Persona

### Profile

- Persona ID: UP-03
- Role: Researcher
- Background: A researcher requesting a specific dataset for
  a stated study purpose.
- Expected usage: Occasional
- Device: Desktop or laptop computer
- Technical knowledge: Familiar with research datasets (assumed)

### Goals

- Request a clearly defined dataset for a specific research purpose.
- Obtain separate patient approval.
- Access only the authorised record versions and fields.
- Fund an approved request using test credits.
- Inspect the corresponding settlement receipt.

### Challenges

- Obtaining explicit patient permission.
- Understanding the permitted scope of a research request.
- Ensuring transparent and verifiable data sharing.
- Preventing access beyond the approved purpose.

### System Needs

- A dedicated research request interface.
- Explicit purpose, scope, expiry and fee information.
- Separate patient approval for research sharing.
- Controlled export of authorised data.
- Verifiable test-credit settlement.
- Protection against duplicate payments.

### Access Limitations

A treatment grant cannot authorise a research export.

Researchers must obtain a separate research grant and satisfy
the approved scope, purpose, expiry and funding conditions.

Test credits have no real monetary value.

### Related User Stories

S9, S10.

## 5. User Needs Summary

| User ID | Role | Primary Need | Access Scope |
| --- | --- | --- | --- |
| UP-01 | Patient | Control health data sharing | Own records and permissions |
| UP-02 | Clinician | Review permitted medical history | Approved treatment scope |
| UP-03 | Researcher | Obtain approved research data | Separate research scope |

## 6. Scope and Limitations

- The prototype uses synthetic health records only.
- No real patient information is collected or processed.
- The blockchain network is a local development network.
- Clinical information and encryption keys remain off-chain.
- A user role alone does not provide access to health records.
- Consent is checked before processing and again before release.
- Unsafe or unavailable release operations must fail closed.
- Release receipts describe authorised release attempts, not
  proof that a recipient has read the information.
- Research compensation uses valueless test credits.
- The system does not provide diagnosis or treatment advice.
- Production deployment and regulatory compliance certification
  are outside the project scope.

## 7. References

- CareConsent Project Proposal:
  End Users, Mission, System Specification, Use Cases,
  User Stories and Exclusions.
- CareConsent Project README.

Stakeholder validation remains pending.
