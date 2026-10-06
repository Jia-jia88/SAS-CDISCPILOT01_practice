# QC summary

Each derived dataset (`ADAM.<name>_V1`) was compared with the CDISC reference dataset of the same name using PROC COMPARE with a unique ID key. Every difference that remained was traced to its source and classified as one of:

- **Known difference — reference dataset**: the reference dataset deviates from the SAP or define.xml, or contains a programming artefact.
- **Known difference — spec ambiguity**: the specifications allow more than one reading; the reading used is documented and flagged for the statistician.
- **Open**: still to be fixed in this repository.

The last dataset-level comparison was run on 2026-09-29.

## ADaM datasets

### ADSL — Open
- **CUMDOSE, AVGDD** are not derived yet. The work-in-progress code for the High Dose titration (54 → 81 → 54 mg) is kept in `adsl.sas` but not executed.
- **DURDIS** is 0.1 month lower than the reference for 80 subjects. Suspected cause: a one-day difference in the day count. DURDSGR1 is not affected.
- The 30.4375-day month used for DURDIS follows common practice in public SAPs; the CDISCPILOT01 SAP does not specify it.

### ADAE — Done
- 1,191 records, all values equal.
- Rule confirmed from the reference data: when the AE start date is imputed (`ASTDTF = 'D'`), ADURN is left missing (all 15 such records).
- define.xml subsets AOCC01FL ("first treatment-emergent dermatological event") to `CQ01NAM = ''`, which excludes every dermatological event. Implemented as `CQ01NAM = 'DERMATOLOGIC EVENTS'`; this removed all 327 AOCC01FL differences (spec defect, to be corrected in define.xml).

### ADLBC / ADLBH — Done, known difference (reference dataset)
- All values equal except **AVISIT** on unscheduled visits (1,482 records in ADLBC, 1,110 in ADLBH): the reference dataset holds `.` where the derived dataset is blank, consistent with a numeric missing value written through `PUT`. Tables use scheduled visits only, so no output is affected.
- define.xml defines `R2A1HI = AVAL / A1LO` and `R2A1LO = AVAL / A1HI`. This contradicts the variable labels and the Hy's Law parameter BILIHY ("Bilirubin 1.5 x ULN" = `R2A1HI > 1.5`). Implemented as `R2A1HI = AVAL / A1HI`; the reference datasets agree.
- The define.xml formula for ALBTRVAL has the opposite sign to the reference data; implemented as `MAX(1.5*ULN - LBSTRESN, LBSTRESN - 0.5*LLN)`, which the reference data follows.

### ADLBHY — Done
- 9,954 records, all values equal.
- The define.xml key lists LBSEQ, which does not exist in ADLBHY; the comparison uses USUBJID, PARAMCD and the analysis visit.

### ADVS — Done, known difference (reference dataset)
- 30,802 records equal.
- 1,337 End of Treatment records on each side do not pair: SAP 11.6 defines End of Treatment as the last visit on or before Week 24, while the reference dataset also uses Week 26. Implemented per SAP (SYSBP, DIABP, PULSE and WEIGHT; TEMP is not in the SAP list).
- The define.xml key is not unique; VSSEQ is needed as an additional key variable.

### ADQSADAS — Done, known difference (spec ambiguity)
- 12,463 records on each side; 12,411 pair and all their values are equal.
- **All 702 analysis records** (Efficacy population, ANL01FL = 'Y', ACTOT, Weeks 8/16/24) are identical, so Tables 14-3.01, 14-3.03 and 14-3.05 are not affected.
- 52 records on each side differ in how a second assessment in the same window is used for LOCF (23 subjects). This program carries forward the window-selected assessment (SAP 8.1: "targeted assessments"; ADaMMSG 4.2: "only considered records used for analysis"); the reference dataset carries forward the latest assessment. Pending statistician confirmation.
- ACTOT uses the SAP 14.2 proration for missing items: missing if 4 or more of the 11 items are missing; otherwise item sum × 70 / (70 − maximum score of the missing items).
- 7 numeric FORMAT attributes differ; define.xml does not specify them.

### ADQSCIBC — Done, known difference (spec ambiguity)
- 730 records on each side; 695 identical, and all 562 observed records are identical.
- The 35 remaining records are LOCF records whose source-record variables (VISIT, VISITNUM, ADY, ADT, AWTDIFF, QSSEQ) differ for the same reason as in ADQSADAS; AVAL is equal.
- Three subjects have no Week 8 assessment; LOCF cannot fill the first post-baseline window and CIBIC+ has no baseline, so no record is created (SAP 8.1).

### ADQSNPIX — Done, known differences (reference dataset)
- 31,140 records pair. NPTOTMN (mean NPI-X total, Weeks 4–24) is verified against CSR Table 14-3.12 instead of the reference dataset:

  | | Placebo | Low dose | High dose |
  |---|---|---|---|
  | n | 78 | 75 | 69 |
  | Mean | 9.3 | 9.1 | 9.6 |
  | SD | 11.18 | 12.10 | 11.60 |
  | Median | 5.5 | 3.8 | 4.4 |

  Averaging all records in the windows instead of the window-selected records gives SD 11.16 / 12.07, so only ANL01FL = 'Y' records are averaged.
- Remaining differences are reference dataset issues: leading characters in AVISIT, a double blank in the NPITM02S PARAM text, CHG/PCHG set to 0 on baseline records (define.xml: post-baseline records only), and 21 NPTOTMN records missing from the reference dataset.
- The define.xml key is not unique; QSSEQ is needed as an additional key variable.

### ADTTE — Done
- 254 records, all values equal.
- 4 FORMAT attributes differ (AGE, AGEGR1N, RACEN, TRTDUR); define.xml does not specify them.
- The EVNTDESC value "Dematologic Event Occured" is spelled as in define.xml.

## Tables

| Table | Compare with | Status |
|---|---|---|
| 14-1.01 Summary of Populations | CSR Table 14-1.01 | Complete |
| 14-1.02 Summary of End of Study Data | CSR Table 14-1.02 | Complete |
| 14-2.01 Demographic and Baseline Characteristics | CSR Table 14-2.01 | Complete; Race p-value 0.604 vs CSR 0.648 because the CSR groups origin into four categories |
| 14-3.01 ADAS-Cog (11) at Week 24 – LOCF | CSR Supporting Table 14-3.01 (PROC GLM output) | Dose response p = 0.245 (CSR 0.2447); Low vs Placebo p = 0.569, difference −0.5 (0.82), 95% CI (−2.08; 1.15) match. High vs Placebo and High vs Low rows still to be confirmed |

For Table 14-3.01, the define.xml dose-response program omits BASE. Implemented per SAP 10.1.1 and the CSR footnote; with BASE the p-value matches the CSR, without it the p-value is 0.2532.
