LIBNAME QSSDTM XPORT "&SDTMPATH/qs.xpt";
LIBNAME ADQSNPIX XPORT "&REFPATH/adqsnpix.xpt";

DATA ADSL_V1;
    SET ADAM.ADSL_V1;
RUN;

DATA QS_SDTM;
	SET QSSDTM.qs;
RUN;

DATA ADQSNPIX_STD;
	SET ADQSNPIX.adqsnpix;
RUN;

/*=================================================================================================
								Derivation Chain 0
==================================================================================================*/
/*STEP 1 Derive ADSL derictly*/

DATA ADSL_STEP_1;
	LENGTH RACE $32;
	SET ADSL_V1 (RENAME = (RACE = _RACE));
	RACE  = _RACE;
	TRTP  = TRT01P;
	TRTPN = TRT01PN;
	KEEP STUDYID SITEID SITEGR1 USUBJID TRTSDT TRTEDT TRTP TRTPN AGE AGEGR1 AGEGR1N RACE
	     RACEN SEX ITTFL EFFFL COMP24FL;
RUN;

/*STEP 2 Derive QS derictly*/
DATA QS_STEP_2;
	SET QS_SDTM;
	WHERE QSTESTCD IN ('NPITM01S','NPITM02S','NPITM03S','NPITM04S','NPITM05S','NPITM06S','NPITM07S'
	,'NPITM08S','NPITM09S','NPITM10S','NPITM11S','NPITM12S','NPTOT','NPTOTMN');
	KEEP STUDYID USUBJID QSDTC QSSEQ QSTESTCD QSTEST QSCAT QSSCAT QSSTRESN QSBLFL VISITNUM VISIT;
RUN;



/*STEP 3 Derive param_lookup*/
/* PARAM text copied verbatim from Define.xml PARAM codelist.
   - 'Agression' (Item C) and 'Eupohoria' (Item F) are Define spellings, retained.
   - NPITM02S: Define has a single blank before 'Score'; reference dataset has
     two (hex '29 20 20 53') -> reference dataset issue, 2360 PARAM diffs.      */



DATA PARAM_LOOKUP;
	LENGTH PARAMCD $8 PARAM $100 PARAMTYP $7;
	INFILE DATALINES DLM='|' DSD TRUNCOVER;
	INPUT PARAMCD $ PARAMN PARAM $ PARAMTYP $;
	DATALINES;
NPITM01S|1|NPI-X Item A (Delusion) Score|
NPITM02S|2|NPI-X Item B (Hallucination) Score|
NPITM03S|3|NPI-X Item C (Agitation/Agression) Score|
NPITM04S|4|NPI-X Item D (Depression/Dysphoria) Score|
NPITM05S|5|NPI-X Item E (Anxiety) Score|
NPITM06S|6|NPI-X Item F (Eupohoria/Elation) Score|
NPITM07S|7|NPI-X Item G (Apathy/Indifference) Score|
NPITM08S|8|NPI-X Item H (Disinhibition) Score|
NPITM09S|9|NPI-X Item I (Irritability/Lability) Score|
NPITM10S|10|NPI-X Item J (Aberrant Motor Behavior) Score|
NPITM11S|11|NPI-X Item K (Night-time Behavior) Score|
NPITM12S|12|NPI-X Item L (Appetite/Eating Change) Score|
NPTOT|13|NPI-X (9) Total Score|
NPTOTMN|14|Mean NPI-X (9) Total (Week 4 to 24)|DERIVED
;
RUN;

/*============================================================================================
							Derivation Chain 1  without NPTOMN
============================================================================================*/
/*STEP 4 Merge QS_STEP_2 and ADSL and PARAM_LOOKUP*/
PROC SORT DATA = adsl_step_1;
	BY STUDYID USUBJID;
RUN;

PROC SORT DATA = QS_STEP_2;
	BY STUDYID USUBJID;
RUN;

DATA ADQSNPIX_STEP_4_MERGE;
	MERGE ADSL_STEP_1 (IN = A) QS_STEP_2(IN = B);
	BY STUDYID USUBJID;
	IF B = 1;
RUN;

PROC SORT DATA = ADQSNPIX_STEP_4_MERGE OUT = CHK_4 (RENAME = (QSTESTCD = PARAMCD));
	BY QSTESTCD;
RUN;

PROC SORT DATA = param_lookup;
	BY PARAMCD;
RUN;

DATA ADQSNPIX_STEP_4;
	MERGE CHK_4 (IN = A) PARAM_LOOKUP(IN = B);
	BY PARAMCD;
	IF A = 1;
RUN;

/*STEP 5 Derive ADT, ADY*/
DATA ADQSNPIX_STEP_5;
	SET ADQSNPIX_STEP_4;
	ADT = INPUT(SUBSTR(QSDTC,1,10), YYMMDD10.);
	FORMAT ADT DATE9.;
	
	IF ADT >= TRTSDT THEN ADY = ADT-TRTSDT+1;
	ELSE IF ADT < TRTSDT AND NOT MISSING(ADT) THEN ADY = ADT-TRTSDT;
RUN;

/*============================================================================================
							Derivation Chain 2 without NPTOMN
============================================================================================*/
/*STEP 6 Derive AVAL, BASE, CHG, ABLFL*/
/* CHG / PCHG on baseline records
   What    : CHG and PCHG left missing on baseline (ABLFL='Y') records.
   Why     : ADaMIG v1.3 leaves baseline/pre-baseline CHG and PCHG to producer
             choice; this study's Define specifies "for post baseline records".
   Verified: all 3555 baseline records missing; reference dataset sets 0
             (inconsistent with Define).
   Decision: Follow Define. */
  
PROC SORT DATA = ADQSNPIX_STEP_5 OUT = ADQSNPIX_STEP_5_SORT;
	BY STUDYID USUBJID PARAMCD ADT ;
RUN;

DATA ADQSNPIX_STEP_6;
	SET ADQSNPIX_STEP_5_SORT ;
	BY STUDYID USUBJID PARAMCD ADT;
	
	RETAIN val ;
	AVAL = QSSTRESN;
	ABLFL = QSBLFL;
	
	IF FIRST.PARAMCD = 1 THEN val = .;
	
	IF QSBLFL = 'Y' THEN val = QSSTRESN;
	
	BASE = val;
	
	IF ABLFL = 'Y' THEN CHG=.;
	ELSE CHG = AVAL - BASE;
	
	IF ABLFL = 'Y' THEN PCHG=.;
	ELSE IF ABLFL ^= 'Y' AND NOT MISSING(BASE) AND BASE ^= 0 THEN PCHG = 100*(CHG/BASE);
	DROP val;
RUN;
/*There are two missing values at USUBJID = '01-704-1017' AND PARAMCD = 'NPITM12S'*/

/*STEP 7 Derive AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU */
DATA ADQSNPIX_STEP_7;
	SET ADQSNPIX_STEP_6;
	LENGTH AWRANGE $9 AVISIT $16;
	IF ADY <= 1 AND NOT MISSING(ADY)THEN DO;
		AVISIT = 'Baseline'; AVISITN = 0; AWRANGE = '<= 1'; AWTARGET = 1; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = . ;AWHI = 1 ;
	END;
	
	ELSE IF ADY >= 2 AND ADY <=21 THEN DO;
		AVISIT = 'Week 2'; AVISITN = 2 ;AWRANGE = '2 - 21' ;AWTARGET = 14 ;AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 2 ;AWHI = 21 ;
	END;
	
	ELSE IF ADY >= 22 AND ADY <=35 THEN DO;
		AVISIT = 'Week 4'; AVISITN = 4 ;AWRANGE = '22 - 35' ;AWTARGET = 28 ;AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 22; AWHI = 35;
	END;
	
	ELSE IF ADY >= 36 AND ADY <= 49 THEN DO;
		AVISIT = 'Week 6'; AVISITN = 6; AWRANGE = '36 - 49'; AWTARGET = 42; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 36; AWHI = 49 ;
	END;
	
	ELSE IF ADY >= 50 AND ADY <= 63 THEN DO;
		AVISIT = 'Week 8'; AVISITN = 8; AWRANGE = '50 - 63'; AWTARGET = 56; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 50; AWHI = 63;
	END;
	ELSE IF ADY >= 64 AND ADY <= 77 THEN DO;
		AVISIT = 'Week 10'; AVISITN = 10; AWRANGE = '64 - 77'; AWTARGET = 70; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 64; AWHI = 77;
	END;
	ELSE IF ADY >= 78 AND ADY <= 91 THEN DO;
		AVISIT = 'Week 12'; AVISITN = 12; AWRANGE = '78 - 91'; AWTARGET = 84; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 78; AWHI = 91;
	END;
	ELSE IF ADY >= 92 AND ADY <= 105 THEN DO;
		AVISIT = 'Week 14'; AVISITN = 14; AWRANGE = '92 - 105'; AWTARGET = 98; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 92; AWHI = 105;
	END;
	ELSE IF ADY >= 106 AND ADY <= 119 THEN DO;
		AVISIT = 'Week 16'; AVISITN = 16; AWRANGE = '106 - 119' ;AWTARGET = 112 ;AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 106; AWHI = 119 ;
	END;
	ELSE IF ADY >= 120 AND ADY <= 133 THEN DO;
		AVISIT = 'Week 18'; AVISITN = 18; AWRANGE = '120 - 133'; AWTARGET = 126; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 120; AWHI = 133; 
	END;
	ELSE IF ADY >= 134 AND ADY <= 147 THEN DO;
		AVISIT = 'Week 20'; AVISITN = 20; AWRANGE = '134 - 147'; AWTARGET = 140 ;AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 134; AWHI = 147; 
	END;
	ELSE IF ADY >= 148 AND ADY <= 161 THEN DO;
		AVISIT = 'Week 22'; AVISITN = 22; AWRANGE = '148 - 161'; AWTARGET = 154; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 148; AWHI = 161 ;
	END;
	ELSE IF ADY >= 162 AND ADY <= 175 THEN DO;
		AVISIT = 'Week 24'; AVISITN = 24; AWRANGE = '162 - 175'; AWTARGET = 168 ;AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 162; AWHI = 175; 
	END;
	ELSE IF ADY > 175 THEN DO;
		AVISIT = 'Week 26'; AVISITN = 26; AWRANGE = '>175'; AWTARGET = 182; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = 176; AWHI = .; 
	END;
	AWU = 'DAYS';
RUN;


/*STEP 8 Derive ANL01FL*/
/* What    : One record per USUBJID/PARAMCD/AVISITN flagged ANL01FL='Y'.
   Why     : SAP 8.2 - within a window, select the record closest to the target
             day (min AWTDIFF); if equidistant, prefer the earlier day (ADY
             ascending). Same-day duplicates (e.g. 01-708-1378 Week 18) broken
             by VISITNUM.
   Verified: ANL_CNT check below returns 0 duplicates; NPTOTMN mean built from
             these records reproduces CSR Table 14-3.12 exactly.
   Decision: Sort + FIRST.AVISITN. (PROC MEANS MIN + MERGE was abandoned: it
             flagged both tied records.)                                       */
PROC SORT DATA = ADQSNPIX_STEP_7 OUT = ADQSNPIX_STEP_7_SORT;
	BY STUDYID USUBJID PARAMCD AVISITN AWTDIFF ADY VISITNUM;
RUN;

DATA ADQSNPIX_STEP_8;
	SET ADQSNPIX_STEP_7_SORT;
	BY STUDYID USUBJID PARAMCD AVISITN AWTDIFF ADY VISITNUM;
	LENGTH ANL01FL $1;
	IF FIRST.AVISITN = 1 AND NOT MISSING(AVISITN) THEN ANL01FL = 'Y';
	DROP QSBLFL QSCAT QSDTC QSSCAT QSSTRESN QSTEST;
RUN;

/* CHECK: at most one ANL01FL='Y' per USUBJID/PARAMCD/AVISITN.
   Expected: 0 observations printed. */
PROC FREQ DATA = ADQSNPIX_STEP_8 NOPRINT;
	WHERE ANL01FL = 'Y';
	TABLES USUBJID * PARAMCD * AVISITN / OUT = ANL_CNT;
RUN;

PROC PRINT DATA = ANL_CNT;
	WHERE COUNT > 1;
RUN;

/*============================================================================================
							Derivation Chain 1 with NPTOTMN
============================================================================================*/
/*STEP 9 Derive AVAL, BASE, CHG, PCHG, ABLFL, ANL01FL, DTYPE, PARAMCD*/

/* 9a. Select NPTOT records in the Week 4 to Week 24 analysis windows.
       What    : Only the window-selected record per window (ANL01FL='Y') is
                 averaged.
       Why     : CSR Table 14-3.12 title "... Week 4 through Week 24 - Windowed";
                 CSR 9.7.1 "all available total scores" = all available
                 WINDOWED values.
       Verified: Efficacy population by TRTPN reproduces CSR 14-3.12 exactly
                 (n 78/75/69; Mean 9.3/9.1/9.6; SD 11.18/12.10/11.60;
                 Median 5.5/3.8/4.4). All-records version gives SD 11.16/12.07
                 -> rejected. 37 EFFFL subjects differ between the two versions.
       Decision: RESOLVED - ANL01FL='Y' only (e.g. 01-701-1023 = 11, not 10.5). */
      
      
DATA FOR_NPTOTMN_MEAN;
	SET ADQSNPIX_STEP_8;
	WHERE AVISITN IN (4,6,8,10,12,14,16,18,20,22,24)
	AND PARAMCD = 'NPTOT'
	AND ANL01FL = 'Y';
	KEEP STUDYID USUBJID PARAMCD AVAL AVISIT AVISITN ANL01FL QSSEQ;
RUN;


/* 9b. AVAL = mean NPTOT per subject. Only subjects with at least one NPTOT
       record in Weeks 4-24 get a row (ADaMMSG 4.2.7: "each patient who had
       any assessments from week 4 through week 24") -> 235 subjects.
       NOTE: Define lists NPTOTMN AVAL as integer, but the mean is not
       rounded (e.g. 1.1818). Datatype mismatch logged as Spec Defect. */
PROC MEANS DATA = FOR_NPTOTMN_MEAN NOPRINT NWAY;
	CLASS STUDYID USUBJID;
	VAR AVAL;
	OUTPUT OUT = NPTOTMN_MEAN (DROP = _TYPE_ _FREQ_) MEAN(AVAL) = AVAL;
RUN;

/*===============================================================================*/
/* CHECK: subjects in ADQSNPIX without an NPTOTMN record.
   Result: 19 subjects (254 in ADSL - 235 with NPTOTMN). None has any NPTOT
   record in AVISITN 4-24; they only have Baseline, Week 2, and/or Week 26.
   Conclusion: expected, no NPTOTMN is derived for them. */
/*There are some subjects who only have AVAL at BASELINE, WEEK2, WEEK26*/
PROC SQL;
CREATE TABLE LOSS_USUBJID AS (SELECT USUBJID
FROM ADQSNPIX_STEP_8
EXCEPT
SELECT USUBJID
FROM NPTOTMN_MEAN
)
;
SELECT QUOTE(USUBJID)
INTO :LOSSUBJID SEPARATED BY ', '
FROM LOSS_USUBJID
;
QUIT;

DATA CHK;
	SET adqsnpix_step_8;
	WHERE USUBJID IN (&LOSSUBJID);
	KEEP USUBJID PARAMCD AVAL AVISIT AVISITN ANL01FL;
RUN;

PROC PRINT DATA = CHK;
RUN;
/*===============================================================================*/

PROC PRINT DATA =NPTOTMN_MEAN;
RUN;

      
DATA NPTOTMN_MEAN_FOR_STACK;
	SET NPTOTMN_MEAN;
	LENGTH PARAMCD $8 AVISIT $16;
	PARAMCD = 'NPTOTMN';
	DTYPE = 'AVERAGE';
	AVISIT = 'Weeks 4-24';
	AVISITN = 98;
RUN;
/* 9c-2. NPTOTMN Baseline records (one per subject with an NPTOT baseline).
   What    : AVISIT='Baseline', AVISITN=0, AVAL=BASE=NPTOT baseline value,
             ABLFL='Y', QSSEQ/QSDTC carried from the source QS record.
   Why     : Baseline source = QS.QSSTRESN where QSTESTCD='NPTOT' and QSBLFL='Y'
             (Define BASE rule for NPTOTMN). Row existence implied by Define QSSEQ
             rule (QS.VISIT=BASELINE) and ARM filter AVISIT='Weeks 4-24'.
             Created for every subject with a baseline, independent of whether a
             Weeks 4-24 mean exists (CSR 14-3.12 Baseline n = 234 EFFFL).
   SPEC DEFECT: Define says "Set ABLFL to missing" for NPTOTMN. ADaMIG v1.3:
             BASE is copied from the ABLFL='Y' record within the same parameter,
             and one must exist when BASE is non-null -> ABLFL='Y' used.
   Verified: 254 rows; reproduces CSR 14-3.12 Baseline (n 79/81/74, Mean
             9.5/8.7/11.9, SD 12.10/9.82/13.70).                               */

DATA NPTOT_BASE;
	SET QS_STEP_2;
	LENGTH PARAMCD $8 AVISIT $16;
	WHERE QSTESTCD = 'NPTOT' AND QSBLFL = 'Y';
	AVAL = QSSTRESN;
	BASE = QSSTRESN;
	PARAMCD = 'NPTOTMN';
	AVISIT = 'Baseline';
	AVISITN = 0;
	ABLFL = 'Y';
	DTYPE = 'AVERAGE';
RUN;

DATA NPTOTMN_FOR_MERGE;
	SET NPTOT_BASE NPTOTMN_MEAN_FOR_STACK;
RUN;

PROC SORT DATA = NPTOTMN_FOR_MERGE;
	BY USUBJID AVISITN;
RUN;

DATA NPTOTMN_FOR_MERGE_BL;
	SET NPTOTMN_FOR_MERGE;
	RETAIN val;
	BY USUBJID AVISITN;
	
	IF FIRST.USUBJID = 1 THEN val = .;
	IF ABLFL = 'Y' THEN val = BASE;
	
	BASE = val;
	ANL01FL = 'Y';
	DROP val;
RUN;

PROC SORT DATA = NPTOTMN_FOR_MERGE_BL;
	BY USUBJID;
RUN;

PROC SORT DATA = ADSL_STEP_1;
	BY USUBJID;
RUN;

DATA NPTOTMN_ADSL;
	MERGE 
	NPTOTMN_FOR_MERGE_BL(IN = A) ADSL_STEP_1(IN = B);
	BY USUBJID;
	IF A = 1;
RUN;

PROC SORT DATA = NPTOTMN_ADSL;
	BY PARAMCD;
RUN;

PROC SORT DATA = PARAM_LOOKUP;
	BY PARAMCD;
RUN;
/* 9f. NPTOTMN window variables (Define gives no value-level rule).
   Baseline row  : NPTOT baseline window ('<= 1', AWTARGET=1, AWHI=1).
   Weeks 4-24 row: AWRANGE/AWLO/AWHI = union of SAP windows Week 4..Week 24
                   (22-175). AWTARGET=98, AWTDIFF=0 aligned to reference
                   dataset; note 98 is the AVISITN code, not a target day as
                   Define defines AWTARGET.
   CHG/PCHG missing per Define; AWU='DAYS' per Define (no condition stated).  */

DATA NPTOTMN_PARAM;
	MERGE NPTOTMN_ADSL(IN = A) PARAM_LOOKUP(IN = B);
	BY PARAMCD;
	IF A = 1;
	LENGTH AWRANGE $9;
	CHG = .;
	PCHG = .;
	AWU = 'DAYS';
	
	ADT = INPUT(SUBSTR(QSDTC,1,10), YYMMDD10.);
	FORMAT ADT DATE9.;
	
	IF ADT >= TRTSDT THEN ADY = ADT-TRTSDT+1;
	ELSE IF ADT < TRTSDT AND NOT MISSING(ADT) THEN ADY = ADT-TRTSDT;
	
	IF AVISITN = 0 THEN DO;
		AWRANGE = '<= 1'; AWTARGET = 1; AWTDIFF = ABS(ADY-AWTARGET);
		AWLO = . ;AWHI = 1 ;
	END;
	
	ELSE IF AVISITN = 98 THEN DO;
		AWRANGE = '22 - 175'; AWTARGET = 98; AWTDIFF = 0;
		AWLO = 22; AWHI = 175; 
	END;
	
	DROP QSTESTCD QSTEST QSSTRESN QSSCAT QSDTC QSCAT QSBLFL;

RUN;

DATA ADQSNPIX_STEP_9;
	SET NPTOTMN_PARAM ADQSNPIX_STEP_8;
RUN;



/*STEP 10 Create final ADQSNPIX: variable order, length, label and format per Define*/
DATA ADQSNPIX_STEP_10 (LABEL = 'NPI-X Item Analysis Data');
	ATTRIB
		STUDYID  LENGTH = $12  LABEL = 'Study Identifier'
		SITEID   LENGTH = $3   LABEL = 'Study Site Identifier'
		SITEGR1  LENGTH = $3   LABEL = 'Pooled Site Group 1'
		USUBJID  LENGTH = $11  LABEL = 'Unique Subject Identifier'
		TRTSDT   LENGTH = 8    LABEL = 'Date of First Exposure to Treatment'  FORMAT = DATE9.
		TRTEDT   LENGTH = 8    LABEL = 'Date of Last Exposure to Treatment'   FORMAT = DATE9.
		TRTP     LENGTH = $20  LABEL = 'Planned Treatment'
		TRTPN    LENGTH = 8    LABEL = 'Planned Treatment (N)'
		AGE      LENGTH = 8    LABEL = 'Age'
		AGEGR1   LENGTH = $5   LABEL = 'Pooled Age Group 1'
		AGEGR1N  LENGTH = 8    LABEL = 'Pooled Age Group 1 (N)'
		RACE     LENGTH = $32  LABEL = 'Race'
		RACEN    LENGTH = 8    LABEL = 'Race (N)'
		SEX      LENGTH = $1   LABEL = 'Sex'
		ITTFL    LENGTH = $1   LABEL = 'Intent-to-Treat Population Flag'
		EFFFL    LENGTH = $1   LABEL = 'Efficacy Population Flag'
		COMP24FL LENGTH = $1   LABEL = 'Completers of Week 24 Population Flag'
		AVISIT   LENGTH = $16  LABEL = 'Analysis Visit'
		AVISITN  LENGTH = 8    LABEL = 'Analysis Visit (N)'
		ADY      LENGTH = 8    LABEL = 'Analysis Relative Day'
		ADT      LENGTH = 8    LABEL = 'Analysis Date'                        FORMAT = DATE9.
		VISITNUM LENGTH = 8    LABEL = 'Visit Number'
		VISIT    LENGTH = $19  LABEL = 'Visit Name'
		PARAM    LENGTH = $100 LABEL = 'Parameter'
		PARAMCD  LENGTH = $8   LABEL = 'Parameter Code'
		PARAMN   LENGTH = 8    LABEL = 'Parameter (N)'
		PARAMTYP LENGTH = $7   LABEL = 'Parameter Type'
		AVAL     LENGTH = 8    LABEL = 'Analysis Value'
		BASE     LENGTH = 8    LABEL = 'Baseline Value'
		CHG      LENGTH = 8    LABEL = 'Change from Baseline'
		PCHG     LENGTH = 8    LABEL = 'Percent Change from Baseline'
		ABLFL    LENGTH = $1   LABEL = 'Analysis Baseline Flag'
		ANL01FL  LENGTH = $1   LABEL = 'Analysis Record Flag 01'
		DTYPE    LENGTH = $7   LABEL = 'Derivation Type'
		AWRANGE  LENGTH = $9   LABEL = 'Analysis Window Valid Relative Range'
		AWTARGET LENGTH = 8    LABEL = 'Analysis Window Target'
		AWTDIFF  LENGTH = 8    LABEL = 'Analysis Window Diff from Target'
		AWLO     LENGTH = 8    LABEL = 'Analysis Window Beginning Timepoint'
		AWHI     LENGTH = 8    LABEL = 'Analysis Window Ending Timepoint'
		AWU      LENGTH = $4   LABEL = 'Analysis Window Unit'
		QSSEQ    LENGTH = 8    LABEL = 'Sequence Number'
	;
	SET ADQSNPIX_STEP_9;
	KEEP STUDYID SITEID SITEGR1 USUBJID TRTSDT TRTEDT TRTP TRTPN AGE AGEGR1 AGEGR1N
	     RACE RACEN SEX ITTFL EFFFL COMP24FL AVISIT AVISITN ADY ADT VISITNUM VISIT
	     PARAM PARAMCD PARAMN PARAMTYP AVAL BASE CHG PCHG ABLFL ANL01FL DTYPE
	     AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU QSSEQ;
RUN;

/* Sort by Define key variables (USUBJID, PARAMCD, AVISIT, ADT);
   AVISITN used instead of AVISIT so that visits sort chronologically. */
PROC SORT DATA = ADQSNPIX_STEP_10;
	BY USUBJID PARAMCD AVISITN ADT;
RUN;


/*STEP 11 QC*/

/* 11a. Record counts by PARAMCD vs reference dataset.
        Expected: all DIFF = 0 except NPTOTMN (468 vs 489, DIFF = -21). */
PROC FREQ DATA = ADQSNPIX_STD NOPRINT;
	TABLES PARAMCD / OUT = CNT_STD (DROP = PERCENT RENAME = (COUNT = N_STD));
RUN;

PROC FREQ DATA = ADQSNPIX_STEP_10 NOPRINT;
	TABLES PARAMCD / OUT = CNT_MY (DROP = PERCENT RENAME = (COUNT = N_MY));
RUN;

DATA CNT_CMP;
	MERGE CNT_STD CNT_MY;
	BY PARAMCD;
	DIFF = SUM(N_STD) - SUM(N_MY);
RUN;

PROC PRINT DATA = CNT_CMP;
RUN;

/* 11b. PROC COMPARE vs reference dataset (key: USUBJID PARAMCD QSSEQ).
   Expected residual differences, all documented:
   - AVISIT  (31140): reference values carry leading characters.
   - PARAM   (2360) : NPITM02S double blank in reference (see STEP 3).
   - CHG     (3555) / PCHG (1064 missing + ~768 float ~1E-14): reference sets 0
                      on baseline records; Define says post-baseline only.
   - AVAL    (175)  : NPTOTMN Weeks 4-24 mean; reference does not reproduce CSR.
   - 21 obs only in derived dataset: NPTOTMN means missing from reference
                      (reference total 214 < CSR EFFFL n 222).
   Both datasets are copied before sorting so that the reference data and the
   Define-key sort order of ADQSNPIX_STEP_10 are left unchanged.              */
DATA STD_CMP;
	SET ADQSNPIX_STD;
RUN;

PROC SORT DATA = STD_CMP;
	BY STUDYID USUBJID PARAMCD QSSEQ;
RUN;

PROC SORT DATA = ADQSNPIX_STEP_10 OUT = MY_CMP;
	BY STUDYID USUBJID PARAMCD QSSEQ;
RUN;

PROC COMPARE BASE = STD_CMP COMPARE = MY_CMP;
	ID STUDYID USUBJID PARAMCD QSSEQ;
RUN;

/* 11c. NPTOTMN vs CSR Table 14-3.12 (Efficacy population) - primary evidence.
   Expected AVISITN=0 : n 79/81/74, Mean 9.5/8.7/11.9, SD 12.10/9.82/13.70
   Expected AVISITN=98: n 78/75/69, Mean 9.3/9.1/9.6,  SD 11.18/12.10/11.60,
                        Median 5.5/3.8/4.4                                     */
PROC MEANS DATA = ADQSNPIX_STEP_10 N MEAN STD MEDIAN MIN MAX MAXDEC = 2;
	WHERE EFFFL = 'Y' AND PARAMCD = 'NPTOTMN' AND ANL01FL = 'Y';
	CLASS AVISITN TRTPN;
	VAR AVAL;
RUN;



DATA ADAM.ADQSNPIX_V1;
	SET ADQSNPIX_STEP_10;
RUN;