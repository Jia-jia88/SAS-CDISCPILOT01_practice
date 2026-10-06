# CDISCPILOT01 — ADaM and TFL programming in SAS

ADaM datasets and summary tables for the public CDISC SDTM/ADaM Pilot study (CDISCPILOT01, Xanomeline in Alzheimer's disease), programmed in SAS from the SDTM data, define.xml and the Statistical Analysis Plan (SAP).

Every dataset was derived from the specifications first and then checked against the CDISC reference ADaM datasets with PROC COMPARE. Each remaining difference was traced back to the SAP, the define.xml or the reference dataset and classified before it was accepted. Summary tables are checked against the numbers in the CSR.

## Highlights

These findings came out of reading the specifications against the data, not out of matching the reference answer.

| Finding | Type | How it was resolved |
|---|---|---|
| The define.xml program for the Table 14-3.01 dose-response analysis omits the baseline covariate that SAP 10.1.1 and the CSR footnote require. | Spec conflict | Implemented per SAP. With BASE the dose-response p-value is 0.2447, identical to CSR Supporting Table 14-3.01; without it, 0.2532. |
| define.xml defines `R2A1HI` as `AVAL / A1LO`, which contradicts its own label and the Hy's Law parameter `BILIHY` ("Bilirubin 1.5 x ULN" = `R2A1HI > 1.5`). | Spec defect | Implemented as `AVAL / A1HI`; confirmed by the reference ADLBC/ADLBH and the downstream ADLBHY. |
| The reference ADVS uses the Week 26 visit for End of Treatment; SAP 11.6 defines EOT as the last visit on or before Week 24. | Reference dataset deviates from SAP | Implemented per SAP; the 1,337 single-sided EOT records are documented. |
| The mean NPI-X total (Weeks 4–24) in the reference dataset does not reproduce CSR Table 14-3.12. | Reference dataset issue | Averaging only the window-selected records (ANL01FL) reproduces the CSR n, mean, SD and median exactly. |
| `ATTRIB` creates a declared variable even when the input has none, so a missing `KEEP` entry produced an all-blank `SITEGR1` with no LOG message. | Silent programming error | Fixed; an all-missing-variable check (`PROC FREQ NLEVELS`) was added to the workflow checklist. |

## Contents

| Area | Items |
|---|---|
| ADaM (10) | ADSL, ADAE, ADLBC, ADLBH, ADLBHY, ADVS, ADQSADAS, ADQSCIBC, ADQSNPIX, ADTTE |
| Tables (4) | 14-1.01 Summary of Populations · 14-1.02 Summary of End of Study Data · 14-2.01 Demographic and Baseline Characteristics · 14-3.01 Primary Endpoint Analysis: ADAS-Cog (11) |
| QC | PROC COMPARE against the CDISC reference datasets, defensive checks (counts, key uniqueness, value ranges) inside each program, table results checked against the CSR |

Methods used in the tables: Fisher's exact test, Pearson chi-square, one-way ANOVA and ANCOVA (dose as a continuous variable for the dose-response test; LS-mean differences for pairwise comparisons).

## QC status

| Dataset | Result against the reference dataset | Status |
|---|---|---|
| ADSL | CUMDOSE and AVGDD not yet derived; DURDIS differs by 0.1 month for 80 subjects | Open |
| ADAE | 1,191 records, all values equal | Done |
| ADLBC | All values equal except AVISIT on unscheduled visits (reference shows `.`) | Done — known difference |
| ADLBH | Same as ADLBC | Done — known difference |
| ADLBHY | 9,954 records, all values equal | Done |
| ADVS | 30,802 records equal; 1,337 EOT records differ by design (SAP 11.6) | Done — known difference |
| ADQSADAS | 12,411 records equal; all 702 analysis records equal; 52 records differ in how a second assessment in the same window is used for LOCF | Done — pending statistician confirmation |
| ADQSCIBC | Observed records equal; 35 LOCF records differ in source-record variables, not in AVAL | Done — pending statistician confirmation |
| ADQSNPIX | NPTOTMN verified against CSR Table 14-3.12; remaining differences are reference dataset issues | Done — known differences |
| ADTTE | 254 records, all values equal | Done |

| Table | Status |
|---|---|
| 14-1.01 Summary of Populations | Complete (RTF) |
| 14-1.02 Summary of End of Study Data | Complete (RTF) |
| 14-2.01 Demographic and Baseline Characteristics | Complete (RTF); numeric display formats being finalised. Race p-value 0.604 vs CSR 0.648 is expected: the CSR groups origin into four categories |
| 14-3.01 Primary Endpoint Analysis: ADAS-Cog (11) | Dose-response p-value and Low vs Placebo results match CSR Supporting Table 14-3.01; remaining rows being checked; RTF output in progress |

Details for every dataset are in [docs/qc_summary.md](docs/qc_summary.md).

## Workflow

Each dataset follows the same six phases, described in [docs/workflow_sop.md](docs/workflow_sop.md):

1. **Scope** — structure, sources and upstream dependencies
2. **Specification** — one executable rule per variable, with a confidence rating
3. **Structure** — records per subject, unique key, pseudo-records
4. **Programming** — in dependency order: structure, keys, values, flags, pseudo-records, attributes
5. **Layered verification** — a layer must pass before the next one is checked
6. **Documentation** — every difference classified as my error, unclear spec, or spec defect

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

1. Download the SDTM and reference ADaM transport files (see [data/README.md](data/README.md)) into one folder.
2. Set `ROOT` in `setup.sas` to that folder and `REPO` in `run_all.sas` to this repository.
3. Submit `run_all.sas` and check the LOG for `ERROR` and `WARNING`.

Developed in SAS Studio (SAS OnDemand for Academics).
