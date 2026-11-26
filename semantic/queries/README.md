# Clinical SPARQL templates (T1–T5)

Clients send only a **template id plus validated parameters**; arbitrary SPARQL, `SERVICE` and updates are not available (docs/contract-interface.md and the proposal's interface model).

| Id | File | Question | Parameters |
|---|---|---|---|
| T1 | t1-antibiotic-use.rq | Recorded antibiotic use overlapping the interval (previous 12 months) | `?patient`, `?windowStart`, `?windowEnd` |
| T2 | t2-active-conditions.rq | Active recorded conditions | `?patient` |
| T3 | t3-active-allergies.rq | Active recorded allergies | `?patient` |
| T4 | t4-symptom-observations.rq | Dated symptom observations in the interval | `?patient`, `?windowStart`, `?windowEnd` |
| T5 | t5-exercise-observations.rq | Dated exercise observations in the interval | `?patient`, `?windowStart`, `?windowEnd` |

## How the backend runs them
1. Read the confirmed grant; verify the requested versions against `scopeCommitment`.
2. Decrypt **only** the granted versions into a fresh in-memory Jena `Dataset`, add `ontology/terminology-catalogue.ttl`.
3. Bind parameters with `ParameterizedSparqlString.setIri/setLiteral` (typed `xsd:dateTime`), never by string concatenation.
4. Execute, project only the SELECT columns below, record PROV (`cc:QueryActivity` `prov:used` the source versions; result `prov:wasDerivedFrom` them), close the dataset.
5. `?patient` is still filtered in every query as a second line of defence against cross-patient leakage.

An empty row set is reported as **no matching records**; the API layer separates it from *denied*, *integrity failure* and *unavailable*.

## Decisions to confirm with the team
- **Interval semantics:** window is half-open `[start, end)`; a medication period is closed `[start, end]`, so a period ending exactly at the window start overlaps and one starting exactly at the window end does not. Evaluation time `2026-12-01T00:00:00Z` → window `[2025-12-01T00:00:00Z, 2026-12-01T00:00:00Z)` as in the proposal's test data. The backend computes `windowStart` (avoids engine-specific duration arithmetic).
- **Counted as use (T1):** MedicationStatement status `active`, `completed`, `stopped`, `on-hold`. Excluded: `entered-in-error`, `intended`, `not-taken`, `unknown`.
- **Observations:** `entered-in-error` and `cancelled` excluded; units shown as recorded, no conversion.
- **Projection:** every row carries `?version` (source version IRI), `?recordedAt` and the record dates; nothing else from the resource.

## Fixtures and expected output
`fixtures/query-fixtures.json` (in this folder) holds the ten labelled cases (`expected` is hand-derived, with a `why`). Dataset: `../fixtures/valid/p01…p03`. Result order = the query's `ORDER BY`.

| Case | Template | Result (labels = `<patient>/<resource id>`) |
|---|---|---|
| QF01 | T1, P01, full grant, `[2025-12-01, 2026-12-01)` | ms08, ms05, ms09, ms04, ms02 |
| QF02 | T1, grant = ms01, ms04, ms05 | ms05, ms04 |
| QF03 | T1, P03 | none |
| QF04 | T1, P01, `[2026-03-09, 2026-10-05)` | ms09, ms04 |
| QF05 | T2, P01 | c01, c02 |
| QF06 | T2, P03 | none |
| QF07 | T3, P01 | a01 |
| QF08 | T3, P01, grant without a01 | none |
| QF09 | T4, P01, `[2026-10-01, 2026-12-01)` | sym2, sym1 |
| QF10 | T5, P01, `[2026-10-01, 2026-12-01)` | ex3, ex2, ex1 |

Boundary records in P01: ms02 ends exactly at window start (in), ms03 ends one second earlier (out), ms07 starts exactly at window end (out), ms06 entered-in-error (out), ms10 only intended (out), ms08 ongoing (in); P02 holds another patient's antibiotic that must never appear.
