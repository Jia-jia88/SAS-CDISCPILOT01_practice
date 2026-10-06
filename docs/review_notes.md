# Review notes

Items found while tidying the programs for this repository. Program logic was **not** changed; each item below needs a decision by the author. Remove this file, or turn the remaining items into a "Known issues" section, before making the repository public.

## High — affects results or the independence of the derivation

| # | Program | Item | Suggested action |
|---|---|---|---|
| H1 | adsl.sas | CUMDOSE and AVGDD are not derived. The work-in-progress code (macro `WIP_CUMDOSE`, not called) selects `TRT01AN = 2`, but TRT01AN holds the dose values 0 / 54 / 81. | Finish the High Dose titration logic with `TRT01AN = 81`, add the 0 and 54 mg arms (`dose × TRTDUR`), then remove CUMDOSE and AVGDD from the DROP in `ADSL_COMPARE`. |
| H2 | adsl.sas, adlbc.sas, adlbh.sas, adlbhy.sas | The final dataset takes its variable list or labels from the reference dataset (`&name_order`, `&LABEL_ADLBC`, `&LABEL_ADLBH`, `&ADLBHY_NAME`, `&LABEL_ADLBHY`). In a real study there is no reference dataset, and the derivation program cannot run without the QC file. | Replace with an explicit ATTRIB from define.xml, as already done in adqsadas.sas, adqsnpix.sas, advs.sas and adtte.sas. |
| H3 | adlbh.sas | `%LET ANRIND_EXP = 1;` is the switch that reproduces the reference dataset behaviour (ANRIND is derived even when a normal-range limit is missing). The comment marks 1 as "verification only". | Decide which rule follows the specification, set the switch accordingly, and record the decision in the issue log. |
| H4 | adlbc.sas, adlbh.sas | `AVISIT = RIGHT(AVISIT);` right-aligns AVISIT (leading blanks), apparently to match the reference dataset. A table program filtering `WHERE AVISIT = 'Week 24'` would select nothing. | Remove `RIGHT()` and accept the AVISIT difference as a known reference-dataset artefact, or filter on AVISITN in table programs. |
| H5 | adsl.sas | DURDIS is 0.1 month lower than the reference for 80 subjects. | Test the day count (`VISIT1DT - DISONSDT` vs `+ 1`) against the reference values. |

## Medium — latent errors that do not change the current results

| # | Program | Item | Suggested action |
|---|---|---|---|
| M1 | adsl.sas, Step 18 | `ELSE IF ITTFL = 'N';` and `ELSE IF SAFFL = 'N';` are subsetting IFs, not assignments. They are never reached today (screen failures are excluded in Step 1), but would silently delete records otherwise. | `ELSE ITTFL = 'N';` and `ELSE SAFFL = 'N';` |
| M2 | adsl.sas, Step 19 | `IF MISSING(DURDIS) THEN DURDSGR1 = '';` is overwritten by the next IF: a missing DURDIS is `< 12` in SAS, so it is grouped as `'<12'`. | Make the second IF an `ELSE IF`, or test `NOT MISSING(DURDIS)`. |
| M3 | adsl.sas, Step 12 | `BMIBLGR1` assigns `'<25'` when BMIBL is missing (`OR MISSING(BMIBL)`). | Check against define.xml; if it only reproduces the reference dataset, document it. |
| M4 | adsl.sas | TRTDUR is derived twice (Steps 17 and 23). | Keep one. |
| M5 | t14_2_01.sas | All summary statistics use the `3.` format, so mean, median, min and max are shown as integers and SD without decimals. The confirmed shell formats are n integer, mean/median/min/max 1 decimal, SD 2 decimals. | Use separate formats per statistic in `CREATE_CON_FREQ`. |
| M6 | t14_2_01.sas | p-values are stored as formatted text (`PVALUE5.3`) and then assigned to a numeric variable (`PVALUE = &&_&VAR._PVALUE;`). A p-value below 0.001 becomes `<.001` and causes a syntax error. | Store the raw p-value in the macro variable and apply the format in PROC REPORT (already done there). |
| M7 | t14_2_01.sas | `CREATE_CAT_FREQ` calls `CALL SYMPUTX('N0', ...)` without a scope. Because N0–N99 already exist globally, the macro overwrites them with the n of the last categorical variable, which is then used in the column headers. It gives the right result today only because BMIBLGR1 has no missing values. | Use different macro variable names inside the macro, or derive the header N once from ADSL. |
| M8 | t14_1_01_02.sas | p-value formats differ: `PVALUE6.4` for completion status, `PVALUE6.` for the two reasons. | Use one format, as shown in the SAP shell. |
| M9 | t14_3_01.sas | No ODS RTF destination, no TITLE1–2 (protocol, page x of y); the High vs Placebo and High vs Low rows are not yet checked against the CSR. | Add the output wrapper used in t14_2_01.sas and complete the CSR check. |

## Low

| # | Program | Item |
|---|---|---|
| L1 | adqscibc.sas | ANL01FL uses PROC MEANS MIN + MERGE, which flags every tied record. There are no ties in this study (537 flags = 537 windows with data, CIBC-006), but ADQSNPIX uses the safer sort + `FIRST.` approach. |
| L2 | adqscibc.sas | The Baseline window sets `AVISITN = 3`; the AVISITN codelist uses 0. CIBIC+ has no baseline records, so no record is affected. |
| L3 | adqsadas.sas | The check "more than one ABLFL = 'Y' per subject and parameter" is a TODO comment without code. |
| L4 | adsl.sas | The pooled sites for SITEGR1 are hard-coded. Deriving them from the SAP 7.1 rule (fewer than 3 subjects in any treatment group) would make the rule visible. |
| L5 | adlbhy.sas | SDTM LB is read but not used. |
| L6 | all | A `PROC FREQ NLEVELS` check for all-missing variables (workflow principle D7) is not yet in the programs. |

## Changes made in this branch that are not purely cosmetic

These are listed so they can be checked when the programs are re-run:

- **adlbc.sas** — removed the last step, `DATA ADAM.ADLBC_V1; SET LB_STEP_14; RUN;`. LB_STEP_14 is created only by adlbh.sas; in a session where ADLBH had already run, this step would have overwritten ADLBC_V1 with hematology data.
- **advs.sas** — removed two PROC FREQ steps that read ADVS_STEP_9 before it is created.
- **adqsadas.sas** — removed the in-place `PROC SORT DATA = ADAS_STEP_9` (learning step; the next steps re-sort with `OUT=`), the intermediate PROC COMPARE with a non-unique ID, and the per-subject QC block that referenced the undefined dataset `_CMP`.
- **adsl.sas** — CUMDOSE/AVGDD work-in-progress code wrapped in an uncalled macro; it previously ran and produced errors because `TRT01AN = 2` selects no subjects.
- **t14_2_01.sas** — the `*_SUMMARY_REVISE` steps now run after the `CREATE_CAT_FREQ` calls that create their input; duplicate `PEARSON_TEST` and `IMPUT_PVAL_CON` calls removed.
- **t14_3_01.sas** — removed the superseded first `STAT_SUMMARY` step and the unfinished Table 14-3.02 code.

Expected result of a clean `run_all.sas` run: the same ADaM datasets and PROC COMPARE results as before.

## Not included in this repository

The SDTM mapping programs (AE, DM, DS, EC, VS from the pharmaverse raw data) belong to a different study and are still in progress. Items noted while reading them:

- AE: `AESCAN = PUT(AEACN, $NY.)` reads AEACN instead of AESCAN; `'Not Submmitted'` typo in the AESDTH format.
- DM: `'NOT HISPANIC OR LATIO'` typo in the ETHNIC format; USUBJID is taken from PATNUM without the study and site prefix.
- DS: the last step reads `ds_rename_time`, which is not created.
- VS: a correction table overwrites collected values; such changes should go back to data management as queries.
