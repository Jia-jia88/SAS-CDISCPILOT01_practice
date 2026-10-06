# CDISCPILOT01 — ADaM and TFL programming in SAS

Ten ADaM datasets and four summary tables for the public CDISC pilot study CDISCPILOT01 (xanomeline in Alzheimer's disease), programmed in SAS from SDTM, define.xml and the Statistical Analysis Plan (SAP), and checked against the CDISC reference datasets and the Clinical Study Report (CSR).

Every variable was derived from the specifications first and only then compared with the reference dataset. Each remaining difference was traced to its source and classified before any code was changed.

## Scope

| Area | Items |
|---|---|
| ADaM datasets (10) | ADSL, ADAE, ADLBC, ADLBH, ADLBHY, ADVS, ADQSADAS, ADQSCIBC, ADQSNPIX, ADTTE |
| Tables (4) | 14-1.01 Summary of Populations · 14-1.02 Summary of End of Study Data · 14-2.01 Demographic and Baseline Characteristics · 14-3.01 Primary Endpoint Analysis: ADAS-Cog (11) |
| Statistical methods | Fisher's exact test, Pearson chi-square, one-way ANOVA, ANCOVA (dose as a continuous term for the dose-response test; LS-mean differences for pairwise comparisons) |
| Structures | ADSL, BDS (including LOCF and End of Treatment records), OCCDS (ADAE), time-to-event (ADTTE) |
| Tools | SAS 9.4 (SAS Studio): DATA step, PROC SQL, PROC GLM, PROC FREQ, PROC REPORT with ODS RTF, macros, PROC COMPARE |

## Key findings: specification and reference-data issues

These came from reading the specifications against the data, not from matching the reference answer.

| Finding | Type | Resolution |
|---|---|---|
| The define.xml analysis program for the Table 14-3.01 dose-response test omits the baseline covariate required by SAP 10.1.1 and the CSR footnote. | Specification conflict | Implemented per SAP. With BASE, p = 0.2447, matching CSR Supporting Table 14-3.01; without it, p = 0.2532. |
| define.xml defines `R2A1HI` as `AVAL / A1LO`, contradicting its own label and the Hy's Law rule `BILIHY` (`R2A1HI > 1.5` = bilirubin above 1.5 x ULN). | Specification defect | Implemented as `AVAL / A1HI`; confirmed by the reference ADLBC/ADLBH and downstream ADLBHY. |
| define.xml subsets `AOCC01FL` ("first treatment-emergent dermatological event") to `CQ01NAM = ''`, which excludes every dermatological event. | Specification defect | Implemented as `CQ01NAM = 'DERMATOLOGIC EVENTS'`; all 327 differences against the reference ADAE disappeared. |
| The reference ADVS takes End of Treatment from Week 26; SAP 11.6 defines it as the last visit on or before Week 24. | Reference data deviates from SAP | Implemented per SAP; the 1,337 affected records are documented. |
| The mean NPI-X total (Weeks 4–24) in the reference ADQSNPIX does not reproduce CSR Table 14-3.12. | Reference data issue | Averaging only window-selected records (`ANL01FL = 'Y'`) reproduces the CSR n, mean, SD and median exactly. |

## Programming errors caught by QC

Most of these were valid SAS that ran without an ERROR or WARNING. They were found by layered PROC COMPARE and defensive checks, and each one became a rule in the [workflow](docs/workflow_sop.md).

| Error | Dataset | How QC exposed it | Fix and safeguard |
|---|---|---|---|
| `MERGE ... BY USUBJID` on data with several records per subject | ADAE | Records paired by position within a subject, with no LOG message | Merge by the full key (`STUDYID USUBJID AESEQ`); check key uniqueness before every MERGE |
| BASE written only on the baseline record (define "`LBSTRESN when ABLFL = Y`" read as *where*, not *from where*) | ADLBC, ADLBH | 20,955 differences in ADLBH, all missing versus value, maximum difference 0 | Retain the baseline value across the parameter, reset at `FIRST.PARAMCD` (ADaMIG: BASE is copied from the `ABLFL = 'Y'` record) |
| Baseline included when flagging the last on-treatment visit | ADLBH | 190 extra End of Treatment records; the first duplicate was a baseline-only parameter | Restrict to post-baseline visits up to Week 24 (SAP); create pseudo-records last, as copies (D1) |
| `0.5 * ULN` typed instead of `0.5 * LLN` in ALBTRVAL | ADLBH | 5,760 differences, constant within each parameter (MCV: −10 = 0.5 × (100 − 80)) | Fixed; a constant difference per parameter is now read as a formula error |
| "ALT or AST above limit" evaluated row by row; missing values checked before the deciding value | ADLBHY | Two TRANSHY records per visit; 23 wrong values in TRANSHY and HYLAW | `PROC TRANSPOSE` to one row per visit before flagging; OR is decided by any `Y`, AND by any `N`, missing only when undecided |
| Downstream step still read a renamed dataset left in WORK from an earlier run | ADLBHY | Four fixes had no effect; the differences did not change between rounds | `run_all.sas` clears WORK before every program |
| Typos that silently create new variables (`CQO1NAM` for `CQ01NAM`; `CALL MISSING(BR22A1LO)`); `ATTRIB` creating an all-blank `SITEGR1` missing from `KEEP` | ADAE, ADLBHY | Variable present but always blank | Compare PROC CONTENTS with define.xml; `PROC FREQ NLEVELS` for all-missing variables (D7) |
| PROC COMPARE `ID` not unique (AVISITN missing) | ADLBH | Duplicate-ID warnings; End of Treatment records paired by order | ID must be unique; stop and fix the ID at the first duplicate warning (D4) |

## QC results

Nine of ten datasets are complete; every remaining difference from the reference is traced to a specific cause. Last full comparison: 2026-09-29.

| Dataset | Result against the CDISC reference dataset (PROC COMPARE) | Status |
|---|---|---|
| ADSL | CUMDOSE and AVGDD not yet derived; DURDIS 0.1 month lower for 80 subjects | Open |
| ADAE | 1,191 records, all values equal | Done |
| ADLBC | All values equal except AVISIT on unscheduled visits (reference shows `.`) | Done, known difference |
| ADLBH | Same as ADLBC | Done, known difference |
| ADLBHY | 9,954 records, all values equal | Done |
| ADVS | 30,802 records equal; 1,337 End of Treatment records differ by design (SAP 11.6) | Done, known difference |
| ADQSADAS | 12,411 of 12,463 records equal, including all 702 analysis records; 52 differ in LOCF source selection | Done, pending statistician confirmation |
| ADQSCIBC | All observed records equal; 35 LOCF records differ in source-record variables, not in AVAL | Done, pending statistician confirmation |
| ADQSNPIX | NPI-X mean total reproduces CSR Table 14-3.12; remaining differences are reference data issues | Done, known difference |
| ADTTE | 254 records, all values equal | Done |

| Table | Status |
|---|---|
| 14-1.01 Summary of Populations | Complete (RTF) |
| 14-1.02 Summary of End of Study Data | Complete (RTF) |
| 14-2.01 Demographic and Baseline Characteristics | Complete (RTF). Race p-value 0.604 vs CSR 0.648 is expected: the CSR groups origin into four categories |
| 14-3.01 Primary Endpoint Analysis: ADAS-Cog (11) | Dose-response p-value and Low Dose vs Placebo match CSR Supporting Table 14-3.01; remaining rows and RTF output in progress |

Details for every dataset are in [docs/qc_summary.md](docs/qc_summary.md).

## Approach

Every dataset follows the same six-phase workflow, so errors surface where they are cheapest to fix ([docs/workflow_sop.md](docs/workflow_sop.md)).

1. **Scope** — structure, source domains, upstream dependencies and inherited variables.
2. **Specification** — one executable rule per variable from define.xml, ADaMIG and the SAP, each rated high, medium or low confidence.
3. **Structure** — records per subject, unique key, and how pseudo-records (End of Treatment, LOCF) are created.
4. **Programming** — in dependency order: structure, keys, values, flags, pseudo-records, attributes.
5. **Layered verification** — defensive checks first (counts, key uniqueness, value ranges), then PROC COMPARE one layer at a time; a layer must pass before the next.
6. **Documentation** — every difference classified as programming error, unclear specification or specification defect, and recorded in an issue log and QC summary.

## Open items

- ADSL: derive CUMDOSE and AVGDD (High Dose titration) and resolve the 0.1-month DURDIS difference.
- Table 14-3.01: check the High Dose vs Placebo and High vs Low rows against the CSR and add the RTF output.
- ADQSADAS and ADQSCIBC: confirm the LOCF source-record rule with a statistician.
- Table 14-2.01: finalise the display format for each summary statistic.

## Repository structure

```
setup.sas              Paths and the ADAM library (edit ROOT once)
run_all.sas            Runs every program in dependency order in a clean session
programs/adam/         One program per ADaM dataset
programs/tfl/          Table programs
docs/qc_summary.md     QC results and known differences per dataset
docs/workflow_sop.md   The six-phase workflow and design principles
data/README.md         Where to get the input data
```

## How to run

1. Download the SDTM and reference ADaM transport files from the [CDISC SDTM/ADaM Pilot Project](https://github.com/cdisc-org/sdtm-adam-pilot-project) (see [data/README.md](data/README.md)) into one folder.
2. Set `ROOT` in `setup.sas` to that folder and `REPO` in `run_all.sas` to this repository.
3. Submit `run_all.sas` and check the LOG for `ERROR` and `WARNING`.

Developed in SAS Studio (SAS OnDemand for Academics).
