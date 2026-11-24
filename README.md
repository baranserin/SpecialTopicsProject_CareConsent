# CareConsent
### Patient-Controlled Health Data and Auditable Sharing

CareConsent is a proposed health-data sharing application that will allow patients to manage selected health records and control access by clinicians and researchers. The project combines semantic technologies for consistent data representation and querying with blockchain-based consent records and encrypted off-chain storage.

## Project Status

The proposal has been submitted, and implementation is starting now.

- **Course:** SEN0401 — Special Topics: Blockchain
- **Semester:** 2026–2027 Fall (term: 2026-09-14 to 2026-12-22)
- **Proposal files:** [`proposal/`](proposal/) (`proposal.json` is the authoritative source for scope, team, modules and the work log)

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
| Frontend | React, TypeScript, MetaMask |
| Backend | Java, Spring Boot |
| Semantic model and queries | FHIR R4, RDF/RDFS, OWL, SPARQL, SHACL, Apache Jena |
| Provenance | PROV-O |
| Smart contracts | Solidity, Foundry, Anvil |
| Encrypted storage | IPFS, AES-256-GCM |

## Team and Responsibilities

The distribution below follows the submitted proposal (`proposal/proposal.json`). Any change must be made in the Proposal Workbench first and then reflected here.

| Member | Student no. | Development roles | Planned share |
|---|---|---|---|
| Bahattin Baran Serin | 2300006459 | Back-end developer, Data engineer, Architect, Release and operations | 20% |
| Elif Naz Akdora | 2300003761 | Front-end developer, Interaction designer | 20% |
| Ayset Mammadova | 2300003102 | Knowledge engineer, Data engineer, Back-end developer | 20% |
| Enes Malik Çolak | 2200005577 | Requirements analyst, Technical writer, Test engineer | 20% |
| Hasan Samet Yurtbilir | 2100004509 | Smart-contract developer, Test engineer | 20% |

### Modules and features

| Module / feature | Responsible | Second member | Epic |
|---|---|---|---|
| Health record import and semantic model (FHIR → RDF/OWL, SHACL, synthetic fixtures) | Ayset Mammadova | Bahattin Baran Serin | Import and model chronic-care records |
| Encrypted storage and record verification (AES-256-GCM, private IPFS, backend API, gateway checks) | Bahattin Baran Serin | Hasan Samet Yurtbilir | Protect and verify stored record versions |
| Consent contracts and access gateway interface (Solidity registry and consent contracts, contract tests, Anvil deployment) | Hasan Samet Yurtbilir | Bahattin Baran Serin | Enforce patient-controlled sharing permissions |
| Clinical query workspace (five SPARQL templates, scoped temporary datasets) | Ayset Mammadova | Bahattin Baran Serin | Answer bounded clinical-history questions |
| Patient dashboard and access history (React screens, MetaMask signing, receipts) | Elif Naz Akdora | Enes Malik Çolak | Explain and verify the patient's sharing history |
| Research sharing and test-credit settlement (settlement contract logic) | Hasan Samet Yurtbilir | Enes Malik Çolak | Demonstrate compensated research sharing |
| Project coordination, acceptance tests and demo package | Enes Malik Çolak | Elif Naz Akdora | Demonstrate compensated research sharing |

**Contract / backend boundary:** the smart-contract owner delivers the Solidity contracts, events, Foundry tests, Anvil deployment script, ABI and an interface document. The backend owner implements the Java EVM adapter and the gateway logic that calls the contracts. Function signatures and identifier formats are agreed jointly before either side builds on them.

### Process leads

| Process | Lead |
|---|---|
| Mission analysis, stakeholder needs, requirements, verification, validation | Enes Malik Çolak |
| Architecture, integration, transition, operation, maintenance, disposal | Bahattin Baran Serin |
| Design definition | Elif Naz Akdora |
| System analysis | Ayset Mammadova |
| Implementation | Hasan Samet Yurtbilir |

### Milestones

| Date | Deliverable | Lead |
|---|---|---|
| 2026-10-23 | Freeze scope, assign modules, agree record, grant and receipt models | Enes Malik Çolak |
| 2026-11-06 | FHIR fixtures, RDF mapping, SHACL checks, first encrypted IPFS round trip | Ayset Mammadova |
| 2026-11-20 | Record registration, patient-signed grants, expiry, revocation and access-control matrix on Anvil | Hasan Samet Yurtbilir |
| 2026-12-04 | Five query templates, scoped datasets, patient dashboard, receipt reconciliation | Elif Naz Akdora |
| 2026-12-11 | Research approvals, test-credit settlement, duplicate-payment checks, integrated demo | Hasan Samet Yurtbilir |
| 2026-12-18 | Acceptance, isolation, failure and latency checks; stakeholder walkthroughs | Enes Malik Çolak |
| 2026-12-22 | Final submission: tagged release, test report, reproducible demo | Enes Malik Çolak |

## Team Workflow

### Repository layout (planned)

```
contracts/   Solidity contracts, Foundry tests, deployment scripts
backend/     Spring Boot gateway, storage pipeline, EVM adapter
semantic/    Ontology, mappings, SHACL shapes, SPARQL templates, fixtures
frontend/    React/TypeScript application
docs/        Requirements, meeting minutes, stakeholder notes, test reports
proposal/    Proposal Workbench files (proposal.json, proposal.md, proposal_lineage.ttl)
```

### Working on a task (code and documentation)

1. Every task has a GitHub Issue with an assignee and an epic label.
2. Update `main` and create a short-lived branch:
   ```bash
   git checkout main && git pull
   git checkout -b feat/<short-name>      # also fix/..., test/..., docs/...
   ```
3. Commit with clear messages and push the branch:
   ```bash
   git push -u origin feat/<short-name>
   ```
4. Open a pull request into `main`. Describe what changed, link the issue (`Closes #12`), explain how to test it and request a reviewer (normally the module's second member).
5. Add your work-log entry right away (see [Work log](#work-log)). You do not need to wait for the merge, because the commit link exists as soon as the commit is pushed.
6. The reviewer reviews the PR (see below). Fix requested changes with new commits on the same branch, then re-request review.
7. After at least one approval, the **PR author merges** using **"Create a merge commit"** and deletes the branch.

### Reviewing a pull request

- Open the PR → **Files changed**. Leave line comments (use **Start a review** to batch them, or **Suggestion** to propose exact code).
- Check out the branch locally and run the tests if needed.
- Finish with **Review changes** → *Comment*, *Approve* or *Request changes*.
- What to check: acceptance criterion of the linked story is met, tests exist and pass, rejection paths are tested, no sensitive data (health contents, raw CIDs, keys) reaches the chain or logs, documentation is updated, nothing outside the agreed scope is added.
- A review is work too: log it as **Verification** with the PR link as evidence.
- If a reviewer does not respond within 48 hours, remind them in the group. If there is still no response, the author may merge and must leave a note on the PR explaining why.

### Team rules

1. **Code and documentation go through a branch and a PR** with at least one review. Never push code directly to `main`.
2. **Exception: `proposal/` is committed directly to `main`** (no branch, no PR). See [Work log](#work-log).
3. **Merge with "Create a merge commit" only.** No squash merges, no rebase merges and no force-pushes, because these change commit hashes and break the commit links used as work-log evidence.
4. **Do not delete the branch of a PR that is closed without merging.** Its commits may be cited in the work log.
5. **Commit under your own GitHub account** (`git config user.name` / `user.email` must match your account).
6. **Meetings and stakeholder contacts are documented** in `docs/meetings/` and `docs/stakeholders/` and committed, so they can be cited as evidence.
7. **Respect module ownership.** Coordinate with the responsible member before changing someone else's module.

## Work log

The course grades the team's work log, which is stored **inside `proposal/proposal.json`**. It is recorded only through the **Proposal Workbench** (`proposal_tool_v4_11_0.html` from the course repository). Each member records their own work as it happens.

### Why the JSON must never be edited by hand

- The Workbench **time-stamps each entry itself** and **chains it to the previous entry with SHA-256** (`seq`, `prev`, `hash`). Entries cannot be edited after they are recorded. A mistake is fixed by adding a **"Correction of an entry"** entry.
- An entry that is changed, removed or inserted by hand breaks the chain and shows up in the **integrity report**. The criterion *"The work log's chain is intact and shows no anomaly"* is worth 3 points of the team grade.
- The integrity check also flags:
  - an entry time-stamped before the entry above it, or in the future;
  - an entry outside the term (2026-09-14 – 2026-12-22);
  - more than 12 hours in one entry, or more than 12 hours for one member on one day;
  - five entries by one member within ten minutes (log as you work, not in batches);
  - the same description used three or more times.
- The Workbench cannot stop a whole log from being rebuilt from scratch. **The commits that carry the log's head fingerprint** in the repository history are what make that visible. So the log must be committed regularly.

### The Workbench has no merge, so there is only one log file

The Workbench keeps data in the browser of each device and has no way to merge two copies. If two members add entries to the same old version, the chain forks and one set of entries is lost. Therefore:

- **`main` is the single source of truth for `proposal/proposal.json`.** Never work from a copy kept in your browser, from WhatsApp or from an older download.
- **Only one person edits the log at a time.** Announce it in the group chat ("🔒 log: <name>") and release it after pushing ("🔓 log #N pushed").

### Adding an entry, step by step

1. Push the work you want to log and copy the commit (or PR) URL.
2. Get the latest proposal from `main`:
   ```bash
   git checkout main && git pull
   ```
3. Open the Workbench → **File › Open file** → `proposal/proposal.json`. Check that the integrity report says the chain is intact.
4. Go to **Work log › Add an entry** and fill in:
   - **Member:** yourself (the page does not verify identity, so only ever select your own name);
   - **Process:** the task type (e.g. Implementation, Integration, Verification, Design definition, Stakeholder needs and requirements);
   - **Story:** the story the work serves (optional, but recommended);
   - **Hours:** 0.25–12, honest;
   - **Description:** what you did, 8 words or more, specific and never repeated;
   - **Evidence:** the commit URL, PR URL or file link.
5. Click **Record entry**, then save the files (**Save file** / ZIP) and copy `proposal.json`, `proposal.md` and `proposal_lineage.ttl` over the files in `proposal/`.
6. **Commit directly to `main` and push**, putting the head fingerprint shown under *Work log › Check* in the message:
   ```bash
   git add proposal/
   git commit -m "worklog: <name> #<entry no> head <first 16 chars of fingerprint>"
   git push
   ```
   Alternatively, use the Workbench's **Post to GitHub** (needs a fine-grained token with *Contents: read and write* on this repository; it writes the fingerprint into the commit message automatically).
7. Announce in the group that the log is released.

If the push is rejected because someone else pushed first, **do not try to merge `proposal.json`**. Pull the latest version, reopen it in the Workbench, record your entry again and push.

### What each member needs (grading)

| Criterion | Proposal stage | Final stage |
|---|---|---|
| Work-log entries | at least 2 | at least 6 |
| Distinct task types (processes) | at least 2 | at least 2 |
| Logged share of team hours | ≥ 50% of the planned share | ≥ 50% of the planned share |
| Entries with an evidence link | — | at least 50% |
| Owned module delivered stories | — | required |

At the final stage the member grade is 50% project + 20% team + 30% individual contribution. A **work-log steward** checks every week that every member has logged work and that the chain is intact.

## Prototype Scope

The prototype will use synthetic health records, private IPFS nodes and a local Ethereum-compatible development network. Research compensation will use valueless test credits.

Revoking consent will prevent future releases through the application. Previously downloaded copies cannot be recalled. Blockchain commitments will provide evidence of registered versions and gateway release attempts, rather than proof of medical accuracy or subsequent human viewing.

## Planned Validation

Evaluation will cover record validation, encryption and integrity checks, consent expiry and revocation, query accuracy, access isolation and duplicate-settlement prevention.

Setup instructions, implementation details and actual evaluation results will be added as development progresses.
