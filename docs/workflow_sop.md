# ADaM development and QC workflow

The aim is to derive every variable from the specifications and expose errors at the point where they are cheapest to fix, instead of writing code first and adjusting it until it matches a reference answer.

Two rules apply throughout:

- No DATA step is written before Phase 1 is complete.
- A verification layer that has not passed blocks the next layer.

## Phase 0 — Scope and dependencies

Answer four questions in the program header before starting:

| Question | Example: ADLBHY |
|---|---|
| What is the structure? | BDS, one record per subject per parameter per analysis visit |
| What are the sources? | ADLBC (ADaM to ADaM), not SDTM |
| Is the upstream dataset validated? | Check before relying on it |
| Which variables are inherited? | AVAL, BASE, ABLFL, R2A1HI, AVISIT/AVISITN |

If an upstream dataset is wrong, PROC COMPARE points at the downstream dataset. When a difference appears, check the inherited variables first.

## Phase 1 — Specification

Sources, in order of how much derivation detail they usually hold:

1. define.xml value-level metadata (the per-parameter rules, often overlooked)
2. define.xml variable-level metadata (source, type, length, codelist)
3. Analysis data reviewer's guide / ADaM dataset descriptions
4. ADaMIG and the ADaM model (general definitions and conformance)
5. SAP and CSR (why the variable exists and how it is analysed)

Output: a derivation table with one executable rule per variable and a confidence rating.

| Confidence | Meaning | Action |
|---|---|---|
| High | Clear text, consistent with the label and its use | Implement |
| Medium | Text exists but is ambiguous or inconsistent elsewhere | Implement and open an issue |
| Low | Not specified | Research first (ADaMIG, published papers); if still unresolved, implement and open an issue |

**Consistency check:** does the rule make sense given the variable label and how it is used? In CDISCPILOT01, define.xml defines `R2A1HI = AVAL / A1LO`, yet the same define.xml defines BILIHY ("Bilirubin 1.5 x ULN") as `R2A1HI > 1.5`, which only holds if `R2A1HI = AVAL / A1HI`. The spec contradicts itself, and the label decides.

## Phase 2 — Structure

Write down before programming:

1. How many records per subject and parameter (visits plus derived records)?
2. What is the unique key?
3. Are there pseudo-records (End of Treatment, LOCF, averages)?
4. Are they copies of existing records or recalculated?

## Phase 3 — Programming in dependency order

Programming order = verification order = dependency order:

| Layer | Content |
|---|---|
| 1 Structure | Read sources, subset, record counts |
| 2 Keys | PARAMCD, PARAM, PARAMN, AVISIT, AVISITN, VISIT, VISITNUM |
| 3 Values | AVAL, BASE, CHG, ranges, derived quantities |
| 4 Flags | ABLFL, ANL01FL, ANRIND/BNRIND, other flags |
| 4.5 Pseudo-records | End of Treatment and similar records, created as copies |
| 5 Attributes | LENGTH, LABEL, FORMAT, variable order, ADSL variables |

## Design principles

| # | Principle | Why |
|---|---|---|
| D1 | Create pseudo-records after all derivations, as pure copies | An End of Treatment record created too early takes part in later calculations: for a "change from previous visit" parameter its previous visit is itself, so AVAL becomes 0 |
| D2 | Sort by group keys, then numeric time keys, then text labels | Text sorts alphabetically: `'Week 16' < 'Week 8'` |
| D3 | Every RETAIN has an `IF FIRST.<group>` reset | Otherwise values leak across groups; the symptom is identical values in unrelated parameters |
| D4 | In PROC COMPARE, ID holds verified variables, VAR holds variables under test | An unverified ID variable turns unequal values into "records missing", and the message disappears |
| D5 | Sort keys must determine a unique order | Anything that uses the previous record (change from previous visit, LOCF) depends on it |
| D6 | Zero is not missing | A lower limit of 0 (e.g. basophils) is usually stored as missing; check the define.xml |
| D7 | Every variable in ATTRIB must exist in the input | ATTRIB creates a declared variable even when the input has none, without a LOG message; run `PROC FREQ NLEVELS` on the final dataset |

## Phase 4 — Layered verification

**Defensive checks** after each step (no reference needed):

```sas
/* Categorical: unexpected values or missing values? */
PROC FREQ DATA = &ds;
    TABLES VISITNUM * AVISIT * AVISITN / LIST MISSING;
RUN;

/* Numeric: plausible range and sign? */
PROC MEANS DATA = &ds N NMISS MIN MEDIAN MAX;
    CLASS PARAMCD;
    VAR &newvar;
RUN;

/* Is the expected key unique? */
PROC SORT DATA = &ds OUT = _KEYCHK NODUPKEY DUPOUT = _DUP;
    BY &key;
RUN;
```

**Comparison with a reference dataset**, one layer at a time:

| Layer | What | ID | Pass criterion |
|---|---|---|---|
| 1 Structure | Record counts per key | — | Same counts |
| 2 Keys | PARAMCD, AVISIT, AVISITN | Stable source keys (e.g. --SEQ) | 0 unequal |
| 3 Values | AVAL, BASE, CHG, ... | Plus the verified keys | 0 unequal |
| 4 Flags | ABLFL, ANL01FL, ANRIND | As above | 0 unequal |
| 5 Attributes | LENGTH, LABEL, FORMAT | PROC CONTENTS | Same attributes |

Read two numbers first: the observations in common (should be all) and the number of variables with unequal values (should be 0). "No unequal values were found" only covers the records that were paired.

When the reference dataset is not available, compare summary statistics with the CSR.

## Phase 5 — Final comparison

Compare all variables. Classify each difference before changing any code:

| Source of the difference | Action |
|---|---|
| My misunderstanding | Fix the program |
| Unclear specification | Implement the most reasonable reading and open an issue |
| Specification or reference dataset is wrong | Implement per the authoritative source and open an issue; never choose a side silently |

## Phase 6 — Documentation

Each dataset ends with an issue log (spec ambiguities and defects, for the specification owner) and a QC summary (what was checked and the result, for review). Issue log fields: ID, dataset/variable, type (spec defect, spec ambiguity, data issue, programming error), severity, description, evidence, impact, proposed action, decision, reference.
