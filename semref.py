"""Reference implementation of the CareConsent semantic rules (no third-party dependencies).

It is NOT the production code (that is Java + Apache Jena in backend/). It exists to:
  * define the FHIR import validation rules (R01-R13) in executable form,
  * produce the RDF fixtures (Turtle + JSON-LD) from FHIR bundles,
  * give an independent evaluation of the five query templates, so the hand-labelled
    expected outputs can be cross-checked until the Jena tests exist.
"""
import hashlib, json, re
from datetime import datetime, timezone

NS = "https://careconsent.example/ns#"
ID = "https://careconsent.example/id/"
CS = "https://careconsent.example/cs/"
SKOS = "http://www.w3.org/2004/02/skos/core#"
XSD = "http://www.w3.org/2001/XMLSchema#"
ATC_SYS = "http://www.whocc.no/atc"
LOCAL_SYS = CS + "demo-catalogue/v0.1"
KIND_SYS = CS + "observation-kind"
OBS_CAT_SYS = "http://terminology.hl7.org/CodeSystem/observation-category"
EVAL_DATE = "2026-12-01"  # evaluation reference date used for "birthDate in the future"

# ---------------------------------------------------------------- terminology catalogue
CATALOGUE_VERSION = "0.1"
CLASS_ANTIBIOTIC = "CLASS-ANTIBIOTIC"
# (system, code, label, origin, broader)
CATALOGUE = [
    ("local", CLASS_ANTIBIOTIC, "Antibacterial for systemic use (demo class, ATC J01)", "local-demo", None),
    ("local", "LC-COND-001", "Type 2 diabetes mellitus (demo)", "local-demo", None),
    ("local", "LC-COND-002", "Essential hypertension (demo)", "local-demo", None),
    ("local", "LC-COND-003", "Acute cystitis (demo)", "local-demo", None),
    ("local", "LC-COND-004", "Asthma (demo)", "local-demo", None),
    ("local", "LC-ALG-001", "Penicillin allergy (demo)", "local-demo", None),
    ("local", "LC-ALG-002", "Peanut allergy (demo)", "local-demo", None),
    ("local", "LC-ALG-003", "Latex allergy (demo)", "local-demo", None),
    ("local", "LC-SYM-001", "Fatigue (demo)", "local-demo", None),
    ("local", "LC-SYM-002", "Dizziness (demo)", "local-demo", None),
    ("local", "LC-EXR-001", "Walking duration (demo)", "local-demo", None),
    ("local", "LC-EXR-002", "Walking distance (demo)", "local-demo", None),
    ("local", "LC-EXR-003", "Cycling distance (demo)", "local-demo", None),
    ("atc", "A10BA02", "Metformin", "standard", None),
    ("atc", "C09AA03", "Lisinopril", "standard", None),
    ("atc", "J01MA02", "Ciprofloxacin", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01CA04", "Amoxicillin", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01XE01", "Nitrofurantoin", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01FA10", "Azithromycin", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01AA02", "Doxycycline", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01DB01", "Cefalexin", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01FA09", "Clarithromycin", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01CR02", "Amoxicillin and beta-lactamase inhibitor", "standard", CLASS_ANTIBIOTIC),
    ("atc", "J01EA01", "Trimethoprim", "standard", CLASS_ANTIBIOTIC),
]

def concept_iri(system, code):
    return CS + ("atc/" if system == "atc" else "demo/") + code

def concept_for_coding(coding):
    sysu = coding.get("system")
    if sysu == ATC_SYS:
        return concept_iri("atc", coding["code"])
    if sysu == LOCAL_SYS:
        return concept_iri("local", coding["code"])
    return None

# ---------------------------------------------------------------- identifiers
def version_hex(label):
    """Opaque version id, shaped like docs/contract-interface.md: sha256("CareConsent:Version:v1:" || uuid).
    Fixtures use a fixed pseudo-uuid 'fixture:<label>' so results are reproducible."""
    return hashlib.sha256(("CareConsent:Version:v1:fixture:" + label).encode()).hexdigest()

def version_iri(label):
    return ID + "version/" + version_hex(label)

def patient_iri(pid):
    return ID + "patient/" + pid

# ---------------------------------------------------------------- validation (import layer)
SUPPORTED = {"Patient", "Condition", "MedicationStatement", "AllergyIntolerance", "Observation"}
COND_STATUS = {"active", "recurrence", "relapse", "inactive", "remission", "resolved"}
COND_VERIF = {"unconfirmed", "provisional", "differential", "confirmed", "refuted", "entered-in-error"}
MED_STATUS = {"active", "completed", "entered-in-error", "intended", "stopped", "on-hold", "unknown", "not-taken"}
ALG_STATUS = {"active", "inactive", "resolved"}
ALG_VERIF = {"unconfirmed", "confirmed", "refuted", "entered-in-error"}
OBS_STATUS = {"registered", "preliminary", "final", "amended", "corrected", "cancelled", "entered-in-error", "unknown"}
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
DT_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
ATC_RE = re.compile(r"^[A-Z][0-9]{2}[A-Z]{2}[0-9]{2}$")

def parse_dt(s):
    """Parse xsd:date (-> midnight UTC) or UTC xsd:dateTime ('...Z'). Returns None when invalid."""
    try:
        if DATE_RE.match(s):
            return datetime.strptime(s, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        if DT_RE.match(s):
            return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None
    return None

def _get(d, path):
    cur = d
    for p in path.split("."):
        if isinstance(cur, list):
            cur = cur[0] if cur else None
        if not isinstance(cur, dict) or p not in cur:
            return None
        cur = cur[p]
    return cur

def validate_bundle(bundle):
    """Returns a list of (rule, field) errors. Rules:
    R01 unsupported resource type   R02 missing patient link      R03 patient reference not in bundle
    R04 duplicate resource id       R05 unsupported modifier ext. R06 invalid date/dateTime (UTC 'Z')
    R07 invalid status code         R08 period end before start   R09 required field missing
    R10 non-numeric quantity value  R11 invalid ATC code          R12 birthDate in the future
    R13 quantity value without unit"""
    errs, seen = [], set()
    res = [e.get("resource", {}) for e in bundle.get("entry", [])]
    patients = {r["id"] for r in res if r.get("resourceType") == "Patient" and "id" in r}
    for r in res:
        rt, rid = r.get("resourceType"), r.get("id")
        if rt not in SUPPORTED:
            errs.append(("R01", f"{rt}")); continue
        if (rt, rid) in seen:
            errs.append(("R04", f"{rt}.id"))
        seen.add((rt, rid))
        if "modifierExtension" in r:
            errs.append(("R05", f"{rt}.modifierExtension"))
        if rt == "Patient":
            b = r.get("birthDate")
            if b is not None:
                d = parse_dt(b)
                if d is None: errs.append(("R06", "Patient.birthDate"))
                elif d > parse_dt(EVAL_DATE): errs.append(("R12", "Patient.birthDate"))
            continue
        # patient link
        sub_field = "patient" if rt == "AllergyIntolerance" else "subject"
        ref = _get(r, sub_field + ".reference")
        if not ref:
            errs.append(("R02", f"{rt}.{sub_field}"))
        elif not ref.startswith("Patient/") or ref.split("/", 1)[1] not in patients:
            errs.append(("R03", f"{rt}.{sub_field}"))
        # required fields / status sets
        def need(path):
            if _get(r, path) in (None, ""): errs.append(("R09", f"{rt}.{path}"))
        def status(path, allowed):
            v = _get(r, path)
            if v is not None and v not in allowed: errs.append(("R07", f"{rt}.{path}"))
        need("meta.lastUpdated")
        lu = _get(r, "meta.lastUpdated")
        if lu and parse_dt(lu) is None: errs.append(("R06", f"{rt}.meta.lastUpdated"))
        if rt == "Condition":
            need("clinicalStatus.coding.code"); need("code.coding.code")
            status("clinicalStatus.coding.code", COND_STATUS); status("verificationStatus.coding.code", COND_VERIF)
            o = r.get("onsetDateTime")
            if o is not None and parse_dt(o) is None: errs.append(("R06", "Condition.onsetDateTime"))
        elif rt == "AllergyIntolerance":
            need("clinicalStatus.coding.code"); need("code.coding.code")
            status("clinicalStatus.coding.code", ALG_STATUS); status("verificationStatus.coding.code", ALG_VERIF)
        elif rt == "MedicationStatement":
            need("status"); need("medicationCodeableConcept.coding.code"); need("effectivePeriod.start")
            status("status", MED_STATUS)
            c = _get(r, "medicationCodeableConcept.coding")
            if c and c[0].get("system") == ATC_SYS and not ATC_RE.match(c[0].get("code", "")):
                errs.append(("R11", "MedicationStatement.medicationCodeableConcept.coding.code"))
            s, e = _get(r, "effectivePeriod.start"), _get(r, "effectivePeriod.end")
            ds, de = (parse_dt(s) if s else None), (parse_dt(e) if e else None)
            if s and ds is None: errs.append(("R06", "MedicationStatement.effectivePeriod.start"))
            if e and de is None: errs.append(("R06", "MedicationStatement.effectivePeriod.end"))
            if ds and de and de < ds: errs.append(("R08", "MedicationStatement.effectivePeriod"))
        elif rt == "Observation":
            need("status"); need("code.coding.code"); need("effectiveDateTime")
            status("status", OBS_STATUS)
            e = r.get("effectiveDateTime")
            if e is not None and parse_dt(e) is None: errs.append(("R06", "Observation.effectiveDateTime"))
            q = r.get("valueQuantity")
            if q is not None:
                v = q.get("value")
                if isinstance(v, bool) or not isinstance(v, (int, float)):
                    errs.append(("R10", "Observation.valueQuantity.value"))
                elif not q.get("unit"):
                    errs.append(("R13", "Observation.valueQuantity.unit"))
    return errs

# ---------------------------------------------------------------- FHIR -> RDF graph
def _lit(v):
    if isinstance(v, bool): return ("lit", str(v).lower(), "boolean")
    if isinstance(v, (int, float)): return ("lit", repr(float(v)) if isinstance(v, float) else str(v), "decimal")
    if DT_RE.match(v): return ("lit", v, "dateTime")
    return ("lit", v, None)

def _date(v):
    return ("lit", v, "date" if DATE_RE.match(v) else "dateTime")

def map_bundle(bundle, label_prefix):
    """Map a *valid* FHIR bundle to {iri: {'types': [...], 'props': {pred: [values]}}}.
    label_prefix = patient id; version labels are '<patient>/<resource id>'."""
    g = {}
    def node(iri, types):
        g[iri] = {"types": types, "props": {}}; return g[iri]
    def add(n, p, v): n["props"].setdefault(p, []).append(v)
    for e in bundle["entry"]:
        r = e["resource"]; rt = r["resourceType"]
        if rt == "Patient":
            n = node(patient_iri(r["id"]), ["PatientProfile"])
            if "birthDate" in r: add(n, "birthDate", _date(r["birthDate"]))
            continue
        pid = (r.get("subject") or r.get("patient"))["reference"].split("/")[1]
        label = f"{pid}/{r['id']}"
        cls = {"Condition": "ConditionRecord", "MedicationStatement": "MedicationStatementRecord",
               "AllergyIntolerance": "AllergyRecord", "Observation": "ObservationRecord"}[rt]
        n = node(version_iri(label), ["HealthRecordVersion", cls])
        add(n, "subject", ("iri", patient_iri(pid)))
        add(n, "resourceType", _lit(rt))
        add(n, "sourceResource", _lit(f"{rt}/{r['id']}"))
        add(n, "recordedAt", _lit(r["meta"]["lastUpdated"]))
        if rt == "Condition":
            add(n, "status", _lit(r["clinicalStatus"]["coding"][0]["code"]))
            if "verificationStatus" in r: add(n, "verificationStatus", _lit(r["verificationStatus"]["coding"][0]["code"]))
            add(n, "concept", ("iri", concept_for_coding(r["code"]["coding"][0])))
            if "onsetDateTime" in r: add(n, "onsetAt", _date(r["onsetDateTime"]))
        elif rt == "AllergyIntolerance":
            add(n, "status", _lit(r["clinicalStatus"]["coding"][0]["code"]))
            if "verificationStatus" in r: add(n, "verificationStatus", _lit(r["verificationStatus"]["coding"][0]["code"]))
            add(n, "concept", ("iri", concept_for_coding(r["code"]["coding"][0])))
        elif rt == "MedicationStatement":
            add(n, "status", _lit(r["status"]))
            add(n, "concept", ("iri", concept_for_coding(r["medicationCodeableConcept"]["coding"][0])))
            add(n, "periodStart", _lit(r["effectivePeriod"]["start"]))
            if "end" in r["effectivePeriod"]: add(n, "periodEnd", _lit(r["effectivePeriod"]["end"]))
        else:  # Observation
            add(n, "status", _lit(r["status"]))
            add(n, "concept", ("iri", concept_for_coding(r["code"]["coding"][0])))
            kind = "other"
            for cat in r.get("category", []):
                for c in cat.get("coding", []):
                    if c.get("system") == OBS_CAT_SYS and c.get("code") == "activity": kind = "exercise"
                    if c.get("system") == KIND_SYS and c.get("code") == "symptom": kind = "symptom"
            add(n, "observationKind", _lit(kind))
            add(n, "effectiveAt", _lit(r["effectiveDateTime"]))
            if "valueQuantity" in r:
                add(n, "valueQuantity", ("lit", str(r["valueQuantity"]["value"]), "decimal"))
                add(n, "unit", _lit(r["valueQuantity"]["unit"]))
    return g

def catalogue_graph():
    g = {}
    for sysk, code, label, origin, broader in CATALOGUE:
        iri = concept_iri(sysk, code)
        props = {"code": [_lit(code)], "label": [_lit(label)], "conceptOrigin": [_lit(origin)],
                 "catalogueVersion": [_lit(CATALOGUE_VERSION)],
                 "system": [("iri", ATC_SYS if sysk == "atc" else LOCAL_SYS)]}
        if broader: props["broader"] = [("iri", concept_iri("local", broader))]
        g[iri] = {"types": ["TerminologyConcept"], "props": props}
    return g

# ---------------------------------------------------------------- serialisation
def _term(v):
    if v[0] == "iri": return f"<{v[1]}>"
    s = v[1].replace("\\", "\\\\").replace('"', '\\"')
    if v[2] == "decimal": return v[1]
    return f'"{s}"' + (f"^^xsd:{v[2]}" if v[2] else "")

def to_turtle(g, header):
    out = [f"# {header}", f"@prefix cc: <{NS}> .", f"@prefix xsd: <{XSD}> .", f"@prefix skos: <{SKOS}> .", ""]
    for iri in sorted(g):
        n = g[iri]; lines = ["a " + ", ".join("cc:" + t for t in n["types"])]
        for p in sorted(n["props"]):
            pred = "skos:broader" if p == "broader" else "cc:" + p
            for v in n["props"][p]: lines.append(f"{pred} {_term(v)}")
        out.append(f"<{iri}> " + " ;\n    ".join(lines) + " .\n")
    return "\n".join(out)

def to_jsonld(g):
    ctx = {"cc": NS, "xsd": XSD, "skos": SKOS}
    graph = []
    for iri in sorted(g):
        n = g[iri]; o = {"@id": iri, "@type": ["cc:" + t for t in n["types"]]}
        for p in sorted(n["props"]):
            key = "skos:broader" if p == "broader" else "cc:" + p
            vals = []
            for v in n["props"][p]:
                if v[0] == "iri": vals.append({"@id": v[1]})
                elif v[2]: vals.append({"@value": v[1] if v[2] != "decimal" else float(v[1]), "@type": "xsd:" + v[2]})
                else: vals.append(v[1])
            o[key] = vals if len(vals) > 1 else vals[0]
        graph.append(o)
    return {"@context": ctx, "@graph": graph}

# ---------------------------------------------------------------- template evaluation (reference semantics)
MED_USE_STATUSES = {"active", "completed", "stopped", "on-hold"}   # entered-in-error, intended, not-taken, unknown excluded
BAD_VERIF = {"entered-in-error", "refuted"}
COND_ACTIVE = {"active", "recurrence", "relapse"}

def _p(n, name):
    v = n["props"].get(name); return v[0][1] if v else None

def _broader_closure(cat, iri):
    seen, stack = set(), [iri]
    while stack:
        c = stack.pop()
        if c in seen: continue
        seen.add(c)
        for v in cat.get(c, {"props": {}})["props"].get("broader", []): stack.append(v[1])
    return seen

def run_template(tid, graph, cat, patient, ws=None, we=None):
    """graph = scoped dataset (only granted versions). Returns list of version IRIs, ordered as the SPARQL ORDER BY."""
    rows = []
    wsd, wed = (parse_dt(ws) if ws else None), (parse_dt(we) if we else None)
    for iri, n in graph.items():
        if "HealthRecordVersion" not in n["types"]: continue
        if n["props"]["subject"][0][1] != patient_iri(patient): continue
        t = n["types"][1]
        if tid == "T1" and t == "MedicationStatementRecord":
            if _p(n, "status") not in MED_USE_STATUSES: continue
            if concept_iri("local", CLASS_ANTIBIOTIC) not in _broader_closure(cat, _p(n, "concept")): continue
            s, e = parse_dt(_p(n, "periodStart")), (parse_dt(_p(n, "periodEnd")) if _p(n, "periodEnd") else None)
            if s < wed and (e is None or e >= wsd): rows.append((-s.timestamp(), iri))
        elif tid == "T2" and t == "ConditionRecord":
            if _p(n, "status") in COND_ACTIVE and _p(n, "verificationStatus") not in BAD_VERIF:
                rows.append((_p(n, "onsetAt") or "", iri))
        elif tid == "T3" and t == "AllergyRecord":
            if _p(n, "status") == "active" and _p(n, "verificationStatus") not in BAD_VERIF:
                rows.append((_p(cat[_p(n, "concept")], "label"), iri))
        elif tid in ("T4", "T5") and t == "ObservationRecord":
            if _p(n, "observationKind") != ("symptom" if tid == "T4" else "exercise"): continue
            if _p(n, "status") in ("entered-in-error", "cancelled"): continue
            ef = parse_dt(_p(n, "effectiveAt"))
            if wsd <= ef < wed: rows.append((-ef.timestamp(), iri))
    return [i for _, i in sorted(rows)]
