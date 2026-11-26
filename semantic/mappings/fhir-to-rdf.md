# FHIR R4 → RDF mapping and import validation (v0.2)

Scope: the four resource types in the proposal (Condition, MedicationStatement, AllergyIntolerance, Observation) plus Patient.
All data are synthetic. `tools/semref.py` is an executable version of everything below.

## Identifiers (opaque, cool-URI style)
| Thing | IRI | Notes |
|---|---|---|
| Patient | `https://careconsent.example/id/patient/{patientId}` | synthetic id only |
| Record version | `https://careconsent.example/id/version/{versionId hex}` | `versionId` = the 64-hex bytes32 registered in `RecordRegistry` (`sha256("CareConsent:Version:v1:" ‖ uuid)`, see docs/contract-interface.md §3.1). No clinical text or patient id inside. Fixtures use the pseudo-uuid `fixture:<patient>/<resource id>`. |
| Concept | `https://careconsent.example/cs/{atc|demo}/{code}` | defined in `ontology/terminology-catalogue.ttl` |

One FHIR resource = one immutable `cc:HealthRecordVersion`. A correction is a new version linked with `cc:replacesVersion`; the earlier version is never rewritten.

## Mapping
| FHIR | RDF |
|---|---|
| `Patient.id`, `birthDate` | `cc:PatientProfile`, `cc:birthDate` (gender, name and contact data are not imported: data minimisation) |
| every record | types `cc:HealthRecordVersion` + `cc:{Condition,MedicationStatement,Allergy,Observation}Record`; `cc:subject`, `cc:resourceType`, `cc:sourceResource` (`Type/id`), `cc:recordedAt` (= `meta.lastUpdated`) |
| `Condition.clinicalStatus` / `verificationStatus` | `cc:status` / `cc:verificationStatus` |
| `Condition.code`, `AllergyIntolerance.code`, `Observation.code`, `MedicationStatement.medicationCodeableConcept` (first coding) | `cc:concept` → catalogue concept |
| `Condition.onsetDateTime` | `cc:onsetAt` (xsd:date or xsd:dateTime as written) |
| `AllergyIntolerance.clinicalStatus` / `verificationStatus` | `cc:status` / `cc:verificationStatus` |
| `MedicationStatement.status`, `effectivePeriod.start/end` | `cc:status`, `cc:periodStart`, `cc:periodEnd` (no end = ongoing) |
| `Observation.status`, `effectiveDateTime` | `cc:status`, `cc:effectiveAt` |
| `Observation.category` | `cc:observationKind`: `activity` (HL7 observation-category) → `exercise`; local code `symptom` → `symptom`; anything else → `other` |
| `Observation.valueQuantity` | `cc:valueQuantity` (xsd:decimal), `cc:unit` as recorded, never converted |

All timestamps are UTC (`…Z`). Dates without time are accepted for `birthDate` and `onsetDateTime` only.

## Terminology
No SNOMED CT licence is assumed. `ontology/terminology-catalogue.ttl` is a small, versioned (`catalogueVersion 0.1`) demonstration catalogue. Concepts are marked `conceptOrigin`: `local-demo` (clearly not SNOMED) or `standard` (WHO ATC codes, demo labels). Antibiotics are the ATC `J01*` concepts linked by `skos:broader` to the local class `CLASS-ANTIBIOTIC`; the catalogue is loaded into every temporary dataset (it contains no patient data).

## Import validation rules (layer 1, Java import validator)
| Rule | Rejects | Negative fixture |
|---|---|---|
| R01 | resource type other than Patient, Condition, MedicationStatement, AllergyIntolerance, Observation (this includes `MedicationRequest`: a prescription alone is not recorded use) | N06, N07 |
| R02 | clinical resource without patient reference | N01–N04 |
| R03 | patient reference not present in the bundle | N05 |
| R04 | duplicate resource id | N20 |
| R05 | `modifierExtension` present | N19 |
| R06 | invalid date / UTC dateTime | N11 |
| R07 | status code outside the allowed FHIR set | N12, N13 |
| R08 | period end before start | N09 |
| R09 | required field missing (`meta.lastUpdated`, status, code, period start, observation time) | N10, N15, N17 |
| R10 | non-numeric quantity value | N08 |
| R11 | ATC code not matching `^[A-Z][0-9]{2}[A-Z]{2}[0-9]{2}$` | N14 |
| R12 | `birthDate` after the evaluation date | N18 |
| R13 | quantity value without unit | N16 |

Layer 2 is SHACL (`shapes/careconsent-shapes.ttl`) on the mapped RDF: cardinalities, status sets, datatypes, opaque version IRI, period order, value-needs-unit. An import is rejected with the rule id and field, before any storage registration.

## Pipeline
1. Parse bundle → 2. layer-1 rules → 3. map to Jena `Model` → 4. SHACL → 5. serialise to Turtle → 6. hand to the storage pipeline (AES-256-GCM → IPFS → digest registration). Turtle/JSON-LD are only for the plaintext working graph; the contract digest covers the encrypted envelope bytes, so it does not depend on RDF serialisation order.
