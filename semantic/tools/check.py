#!/usr/bin/env python3
"""Self-checks for the semantic module. Exit code 0 = all good.  Run: python3 semantic/tools/check.py"""
import json, pathlib, sys
import semref as S

ROOT = pathlib.Path(__file__).resolve().parent.parent
fails = []
def check(ok, msg):
    print(("PASS " if ok else "FAIL ") + msg)
    if not ok: fails.append(msg)

# 1. valid fixtures pass import validation
bundles = {}
for pid in ("P01", "P02", "P03"):
    b = json.loads((ROOT / "fixtures/valid" / f"{pid.lower()}.fhir.json").read_text())
    bundles[pid] = b
    check(S.validate_bundle(b) == [], f"valid fixture {pid} has no validation errors")

# 2. each negative fixture is rejected with exactly its expected rule + field
manifest = json.loads((ROOT / "fixtures/invalid/manifest.json").read_text())
check(len(manifest) == 20, "20 negative fixtures")
for m in manifest:
    b = json.loads((ROOT / "fixtures/invalid" / m["file"]).read_text())
    errs = S.validate_bundle(b)
    check(errs == [(m["expectedRule"], m["expectedField"])], f"{m['file']} -> {m['expectedRule']} {m['expectedField']} (got {errs})")

# 3. Turtle/JSON-LD fixtures are in sync with the mapper
for pid, b in bundles.items():
    g = S.map_bundle(b, pid)
    ttl = (ROOT / "fixtures/valid" / f"{pid.lower()}.ttl").read_text()
    jl = json.loads((ROOT / "fixtures/valid" / f"{pid.lower()}.jsonld").read_text())
    check(ttl.split("\n", 1)[1].strip() == S.to_turtle(g, "x").split("\n", 1)[1].strip() and len(jl["@graph"]) == len(g), f"RDF fixtures for {pid} match mapper output")

# 4. query fixtures: hand-labelled expectations == reference evaluation on the scoped dataset
cat = S.catalogue_graph()
graph_all, labels = {}, {}
for pid, b in bundles.items():
    g = S.map_bundle(b, pid)
    for e in b["entry"]:
        r = e["resource"]
        if r["resourceType"] != "Patient": labels[S.version_iri(f"{pid}/{r['id']}")] = f"{pid}/{r['id']}"
    graph_all.update(g)
qfs = json.loads((ROOT / "queries/fixtures/query-fixtures.json").read_text())
check(len(qfs) == 10, "10 query fixtures")
for q in qfs:
    if q["grant"]["mode"] == "all":
        scoped = {k: v for k, v in graph_all.items()}   # 'all' = every version in the dataset (other patients are filtered by ?patient)
    else:
        allowed = {S.version_iri(l) for l in q["grant"]["versions"]}
        scoped = {k: v for k, v in graph_all.items() if "HealthRecordVersion" not in v["types"] or k in allowed}
    w = q.get("window", [None, None])
    got = [labels[i] for i in S.run_template(q["template"], scoped, cat, q["patient"], w[0], w[1])]
    check(got == q["expected"], f"{q['id']} {q['template']} {q['patient']} -> {got}")

# 5. opaque ids: no clinical text in version IRIs, 64-hex format
import re
ok = all(re.fullmatch(r"https://careconsent\.example/id/version/[0-9a-f]{64}", i) for i in labels)
check(ok, "all version IRIs are opaque 64-hex identifiers")
print("\nRESULT:", "ALL CHECKS PASSED" if not fails else f"{len(fails)} FAILED")
sys.exit(1 if fails else 0)
