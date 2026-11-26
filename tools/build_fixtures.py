#!/usr/bin/env python3
"""Regenerates every file under fixtures/ and ontology/terminology-catalogue.ttl.
Run from anywhere:  python3 semantic/tools/build_fixtures.py"""
import json, pathlib, copy
import semref as S

ROOT = pathlib.Path(__file__).resolve().parent.parent
UPD = "2026-11-06T09:00:00Z"
def meta(): return {"lastUpdated": UPD}
def cc(code, display=None):
    return {"coding": [{"system": S.LOCAL_SYS, "code": code, **({"display": display} if display else {})}]}
def status_cc(code): return {"coding": [{"code": code}]}

def pat(pid, birth=None):
    r = {"resourceType": "Patient", "id": pid}
    if birth: r["birthDate"] = birth
    return r
def cond(i, pid, code, st, verif=None, onset=None):
    r = {"resourceType": "Condition", "id": i, "meta": meta(), "clinicalStatus": status_cc(st), "code": cc(code),
         "subject": {"reference": f"Patient/{pid}"}}
    if verif: r["verificationStatus"] = status_cc(verif)
    if onset: r["onsetDateTime"] = onset
    return r
def alg(i, pid, code, st, verif=None):
    r = {"resourceType": "AllergyIntolerance", "id": i, "meta": meta(), "clinicalStatus": status_cc(st), "code": cc(code),
         "patient": {"reference": f"Patient/{pid}"}}
    if verif: r["verificationStatus"] = status_cc(verif)
    return r
def med(i, pid, atc, st, start, end=None):
    per = {"start": start}
    if end: per["end"] = end
    return {"resourceType": "MedicationStatement", "id": i, "meta": meta(), "status": st,
            "medicationCodeableConcept": {"coding": [{"system": S.ATC_SYS, "code": atc}]},
            "subject": {"reference": f"Patient/{pid}"}, "effectivePeriod": per}
def obs(i, pid, code, kind, eff, value=None, unit=None):
    cat = ({"system": S.OBS_CAT_SYS, "code": "activity"} if kind == "exercise" else {"system": S.KIND_SYS, "code": "symptom"})
    r = {"resourceType": "Observation", "id": i, "meta": meta(), "status": "final", "category": [{"coding": [cat]}],
         "code": cc(code), "subject": {"reference": f"Patient/{pid}"}, "effectiveDateTime": eff}
    if value is not None: r["valueQuantity"] = {"value": value, "unit": unit}
    return r
def bundle(bid, resources):
    return {"resourceType": "Bundle", "id": bid, "type": "collection",
            "entry": [{"fullUrl": f"urn:fixture:{r['resourceType']}/{r['id']}", "resource": r} for r in resources]}

# ------------------------------------------------------------------ valid synthetic patients
P01 = [pat("P01", "1968-04-12"),
  # medication statements (antibiotic boundary cases, see queries/README.md)
  med("ms01", "P01", "A10BA02", "active",    "2015-06-15T00:00:00Z"),                                  # not an antibiotic
  med("ms02", "P01", "J01MA02", "completed", "2025-11-24T00:00:00Z", "2025-12-01T00:00:00Z"),          # ends exactly at window start -> overlaps
  med("ms03", "P01", "J01CA04", "completed", "2025-11-20T00:00:00Z", "2025-11-30T23:59:59Z"),          # ends 1 s before window -> outside
  med("ms04", "P01", "J01XE01", "completed", "2026-03-02T00:00:00Z", "2026-03-09T23:59:59Z"),
  med("ms05", "P01", "J01FA10", "completed", "2026-10-05T00:00:00Z", "2026-10-10T00:00:00Z"),
  med("ms06", "P01", "J01AA02", "entered-in-error", "2026-06-01T00:00:00Z", "2026-06-08T00:00:00Z"),   # excluded: entered in error
  med("ms07", "P01", "J01DB01", "active",    "2026-12-01T00:00:00Z", "2026-12-08T00:00:00Z"),          # starts exactly at window end -> outside
  med("ms08", "P01", "J01FA09", "active",    "2026-11-20T00:00:00Z"),                                  # ongoing, no end
  med("ms09", "P01", "J01CR02", "completed", "2026-05-01T00:00:00Z", "2026-05-07T00:00:00Z"),
  med("ms10", "P01", "J01EA01", "intended",  "2026-11-25T00:00:00Z"),                                  # intended only -> not recorded use
  # conditions
  cond("c01", "P01", "LC-COND-001", "active",   "confirmed", "2015-06-01"),
  cond("c02", "P01", "LC-COND-002", "active",   "confirmed", "2017-02-20"),
  cond("c03", "P01", "LC-COND-003", "resolved", "confirmed", "2026-03-01"),
  cond("c04", "P01", "LC-COND-004", "inactive", "confirmed", "2001-09-01"),
  cond("c05", "P01", "LC-COND-001", "active",   "entered-in-error", "2015-06-01"),
  # allergies
  alg("a01", "P01", "LC-ALG-001", "active",   "confirmed"),
  alg("a02", "P01", "LC-ALG-002", "inactive", "confirmed"),
  alg("a03", "P01", "LC-ALG-003", "active",   "entered-in-error"),
  # symptom / exercise observations (different units, one without value)
  obs("sym0", "P01", "LC-SYM-001", "symptom",  "2026-08-01T08:00:00Z", 6, "score"),
  obs("sym1", "P01", "LC-SYM-001", "symptom",  "2026-10-20T08:00:00Z", 3, "score"),
  obs("sym2", "P01", "LC-SYM-002", "symptom",  "2026-11-15T09:30:00Z"),
  obs("ex0",  "P01", "LC-EXR-003", "exercise", "2026-09-20T17:00:00Z", 25, "km"),
  obs("ex1",  "P01", "LC-EXR-001", "exercise", "2026-11-02T07:00:00Z", 45, "min"),
  obs("ex2",  "P01", "LC-EXR-002", "exercise", "2026-11-09T07:00:00Z", 3.2, "km"),
  obs("ex3",  "P01", "LC-EXR-002", "exercise", "2026-11-16T07:00:00Z", 2500, "m"),
]
P02 = [pat("P02", "1975-01-30"),   # another patient: must never leak into P01 results
  med("ms01", "P02", "J01FA10", "completed", "2026-06-01T00:00:00Z", "2026-06-06T00:00:00Z"),
  cond("c01", "P02", "LC-COND-001", "active", "confirmed", "2020-05-05"),
  alg("a01", "P02", "LC-ALG-001", "active", "confirmed"),
  obs("sym1", "P02", "LC-SYM-001", "symptom", "2026-10-22T08:00:00Z", 5, "score")]
P03 = [pat("P03", "1990-07-07"),   # no antibiotics, no active conditions/allergies, no observations
  cond("c01", "P03", "LC-COND-004", "inactive", "confirmed", "2005-01-01")]
PATIENTS = {"P01": P01, "P02": P02, "P03": P03}

def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True); path.write_text(text, encoding="utf-8")

def main():
    fx = ROOT / "fixtures"
    for pid, res in PATIENTS.items():
        b = bundle(f"synthetic-{pid}", res)
        assert S.validate_bundle(b) == [], (pid, S.validate_bundle(b))
        g = S.map_bundle(b, pid)
        low = pid.lower()
        write(fx / "valid" / f"{low}.fhir.json", json.dumps(b, indent=2, ensure_ascii=False) + "\n")
        write(fx / "valid" / f"{low}.ttl", S.to_turtle(g, f"Expected RDF for {low}.fhir.json (synthetic; generated by tools/build_fixtures.py)") + "\n")
        write(fx / "valid" / f"{low}.jsonld", json.dumps(S.to_jsonld(g), indent=2, ensure_ascii=False) + "\n")
    write(ROOT / "ontology" / "terminology-catalogue.ttl",
          S.to_turtle(S.catalogue_graph(), "Local demonstration terminology catalogue v" + S.CATALOGUE_VERSION +
                      " - 'local-demo' concepts are NOT SNOMED CT; 'standard' concepts are WHO ATC codes with demo labels") + "\n")

    # --------------------------------------------------------------- 20 negative fixtures
    def nb(extra, patient=True, patient_res=None):
        base = [patient_res or pat("P01", "1968-04-12")] if patient else []
        return bundle("negative", base + extra)
    neg = []
    def add(n, rule, field, desc, b): neg.append((n, rule, field, desc, b))
    c = cond("c1", "P01", "LC-COND-001", "active", "confirmed", "2015-06-01")
    m = med("m1", "P01", "J01XE01", "completed", "2026-03-02T00:00:00Z", "2026-03-09T00:00:00Z")
    a = alg("a1", "P01", "LC-ALG-001", "active", "confirmed")
    o = obs("o1", "P01", "LC-SYM-001", "symptom", "2026-10-20T08:00:00Z", 3, "score")
    def without(r, *path):
        r = copy.deepcopy(r); d = r
        for p in path[:-1]: d = d[p]
        d.pop(path[-1]); return r
    def setp(r, path, val):
        r = copy.deepcopy(r); d = r
        for p in path[:-1]: d = d[p]
        d[path[-1]] = val; return r
    add(1, "R02", "Condition.subject", "Condition without patient reference", nb([without(c, "subject")]))
    add(2, "R02", "MedicationStatement.subject", "MedicationStatement without patient reference", nb([without(m, "subject")]))
    add(3, "R02", "AllergyIntolerance.patient", "AllergyIntolerance without patient reference", nb([without(a, "patient")]))
    add(4, "R02", "Observation.subject", "Observation without patient reference", nb([without(o, "subject")]))
    add(5, "R03", "Condition.subject", "Condition refers to Patient/NOPE which is not in the bundle", nb([setp(c, ["subject", "reference"], "Patient/NOPE")]))
    add(6, "R01", "Encounter", "Unsupported resource type Encounter", nb([{"resourceType": "Encounter", "id": "e1"}]))
    add(7, "R01", "MedicationRequest", "Prescription (MedicationRequest) is not accepted as recorded use", nb([{"resourceType": "MedicationRequest", "id": "r1", "subject": {"reference": "Patient/P01"}}]))
    add(8, "R10", "Observation.valueQuantity.value", "Observation value is the string 'high'", nb([setp(o, ["valueQuantity", "value"], "high")]))
    add(9, "R08", "MedicationStatement.effectivePeriod", "Medication period ends before it starts", nb([setp(m, ["effectivePeriod", "end"], "2026-03-01T00:00:00Z")]))
    add(10, "R09", "MedicationStatement.effectivePeriod.start", "Medication period has no start", nb([without(m, "effectivePeriod", "start")]))
    add(11, "R06", "Condition.onsetDateTime", "Onset date 2026-13-45 is not a calendar date", nb([setp(c, ["onsetDateTime"], "2026-13-45")]))
    add(12, "R07", "Condition.clinicalStatus.coding.code", "Unknown clinicalStatus code 'maybe'", nb([setp(c, ["clinicalStatus", "coding"], [{"code": "maybe"}])]))
    add(13, "R07", "MedicationStatement.status", "Unknown medication status 'taking-ish'", nb([setp(m, ["status"], "taking-ish")]))
    add(14, "R11", "MedicationStatement.medicationCodeableConcept.coding.code", "ATC code 'J01' is incomplete", nb([setp(m, ["medicationCodeableConcept", "coding"], [{"system": S.ATC_SYS, "code": "J01"}])]))
    add(15, "R09", "Observation.effectiveDateTime", "Observation without effective time", nb([without(o, "effectiveDateTime")]))
    add(16, "R13", "Observation.valueQuantity.unit", "Observation value without unit", nb([setp(o, ["valueQuantity"], {"value": 3})]))
    add(17, "R09", "AllergyIntolerance.clinicalStatus.coding.code", "Allergy without clinicalStatus", nb([without(a, "clinicalStatus")]))
    add(18, "R12", "Patient.birthDate", "Patient born after the evaluation date", nb([], patient_res=pat("P01", "2030-01-01")))
    add(19, "R05", "Condition.modifierExtension", "Resource carries an unsupported modifierExtension", nb([setp(c, ["modifierExtension"], [{"url": "urn:x", "valueBoolean": True}])]))
    add(20, "R04", "Condition.id", "Two Condition resources share the id c1", nb([c, copy.deepcopy(c)]))
    manifest = []
    for n, rule, field, desc, b in neg:
        name = f"N{n:02d}.json"
        write(fx / "invalid" / name, json.dumps(b, indent=2) + "\n")
        manifest.append({"file": name, "expectedRule": rule, "expectedField": field, "description": desc})
    write(fx / "invalid" / "manifest.json", json.dumps(manifest, indent=2) + "\n")

    # --------------------------------------------------------------- 10 labelled query fixtures (hand-derived)
    W_Y = ["2025-12-01T00:00:00Z", "2026-12-01T00:00:00Z"]   # evaluation interval from the proposal's test data
    allp01 = {"mode": "all"}
    qf = [
      {"id": "QF01", "template": "T1", "patient": "P01", "window": W_Y, "grant": allp01,
       "expected": ["P01/ms08", "P01/ms05", "P01/ms09", "P01/ms04", "P01/ms02"],
       "why": "Antibiotic periods overlapping [2025-12-01, 2026-12-01). ms02 ends exactly at the window start (included, closed period end); ms08 is ongoing. Excluded: ms01 non-antibiotic, ms03 ends 1 s early, ms06 entered-in-error, ms07 starts exactly at window end, ms10 only intended."},
      {"id": "QF02", "template": "T1", "patient": "P01", "window": W_Y,
       "grant": {"mode": "versions", "versions": ["P01/ms01", "P01/ms04", "P01/ms05"]},
       "expected": ["P01/ms05", "P01/ms04"],
       "why": "Grant lists only ms01, ms04 and ms05. Antibiotics ms02, ms08 and ms09 exist but are outside the grant, so they never enter the temporary dataset."},
      {"id": "QF03", "template": "T1", "patient": "P03", "window": W_Y, "grant": {"mode": "all"},
       "expected": [], "why": "Patient with no antibiotic records: empty result (the API distinguishes this from denial)."},
      {"id": "QF04", "template": "T1", "patient": "P01", "window": ["2026-03-09T00:00:00Z", "2026-10-05T00:00:00Z"], "grant": allp01,
       "expected": ["P01/ms09", "P01/ms04"],
       "why": "ms04 ends 2026-03-09T23:59:59Z, after the window start; ms05 starts exactly at the window end and is excluded."},
      {"id": "QF05", "template": "T2", "patient": "P01", "grant": allp01,
       "expected": ["P01/c01", "P01/c02"],
       "why": "c01, c02 active. c03 resolved, c04 inactive, c05 active but entered-in-error."},
      {"id": "QF06", "template": "T2", "patient": "P03", "grant": {"mode": "all"},
       "expected": [], "why": "Only an inactive condition exists: empty result."},
      {"id": "QF07", "template": "T3", "patient": "P01", "grant": allp01,
       "expected": ["P01/a01"], "why": "a01 active. a02 inactive, a03 active but entered-in-error."},
      {"id": "QF08", "template": "T3", "patient": "P01",
       "grant": {"mode": "versions", "versions": ["P01/a02", "P01/a03", "P01/c01"]},
       "expected": [], "why": "The only matching allergy (a01) is not granted: the permitted graph holds no matching record."},
      {"id": "QF09", "template": "T4", "patient": "P01", "window": ["2026-10-01T00:00:00Z", "2026-12-01T00:00:00Z"], "grant": allp01,
       "expected": ["P01/sym2", "P01/sym1"],
       "why": "Symptoms inside the window, newest first. sym2 has no value or unit (optional fields missing); sym0 (August) is outside."},
      {"id": "QF10", "template": "T5", "patient": "P01", "window": ["2026-10-01T00:00:00Z", "2026-12-01T00:00:00Z"], "grant": allp01,
       "expected": ["P01/ex3", "P01/ex2", "P01/ex1"],
       "why": "Exercise observations in the window: 2500 m, 3.2 km and 45 min are returned as stored (no unit conversion). ex0 (September) is outside."},
    ]
    write(ROOT / "queries" / "fixtures" / "query-fixtures.json", json.dumps(qf, indent=2) + "\n")
    print("fixtures written:", len(PATIENTS), "valid patients,", len(neg), "negative,", len(qf), "query fixtures")

if __name__ == "__main__":
    main()
