/*==========================================================================
  Program   : adqsadas.sas
  Study     : CDISCPILOT01
  Purpose   : Derive ADQSADAS (ADAS-Cog Analysis Dataset, BDS)
              - 14 item parameters (ACITM01-ACITM14) and the ADAS-Cog(11)
                total (ACTOT) with SAP 14.2 proration for missing items
              - Analysis windows from ADY (SAP 8.2): Baseline, Week 8/16/24
              - ANL01FL: record closest to the target day in each window
              - LOCF records for empty windows (ACTOT only, DTYPE = 'LOCF')
  Input     : ADAM.ADSL_V1, SDTM QS (ADAS-Cog)
              Reference ADQSADAS (adqsadas.xpt) - used for QC comparison
  Output    : ADAM.ADQSADAS_V1
  Spec      : CDISCPILOT01 define.xml (ADQSADAS); SAP 8.1, 8.2, 14.2
  Run after : setup.sas, adsl.sas
  QC result : 702 / 702 analysis records match the reference dataset;
              remaining differences are documented in docs/qc_summary.md.
==========================================================================*/

LIBNAME QSSDTM XPORT "&SDTMPATH/qs.xpt";
LIBNAME ADQSADAS XPORT "&REFPATH/adqsadas.xpt";

DATA ADSL_V1;
    SET ADAM.ADSL_V1;
RUN;

DATA QS_SDTM;
	SET QSSDTM.qs;
RUN;

DATA ADQSADAS_STD;
	SET ADQSADAS.adqsadas;
RUN;

/*===================================================================================================
						Derivation Chain 0
==================================================================================================*/

/*STEP 1 Derive variables from ADSL directly*/
DATA ADSL_STEP_1;
	LENGTH RACE $32;
	SET ADSL_V1;
	TRTP = TRT01P;
	TRTPN = TRT01PN;
	TRTA = TRT01A;
	TRTAN = TRT01AN;
	KEEP STUDYID SUBJID SITEID SITEGR1 USUBJID TRTP TRTPN TRTA TRTAN TRTSDT TRTEDT 
	AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL COMP24FL DSRAEFL EFFFL ITTFL;
RUN;


/*STEP 2 Derive variables from QS directly*/
DATA QS_STEP_2;
	SET QS_SDTM;
	WHERE QSCAT = "ALZHEIMER'S DISEASE ASSESSMENT SCALE";
	DROP QSSCAT;
RUN;

/*STEP 3 Merge two datasets, QS_STEP_2 and ADSL*/
PROC SORT DATA = QS_STEP_2;
	BY STUDYID USUBJID;
RUN;

PROC SORT DATA = ADSL_STEP_1;
	BY STUDYID USUBJID;
RUN;

DATA ADAS_STEP_3;
	MERGE QS_STEP_2(IN = A) ADSL_STEP_1;
	BY STUDYID USUBJID;
	IF A = 1;
	DROP DOMAIN QSSTRESC;
RUN;

/*STEP 4 Merge ADAS_STEP_3 and PARAMCD_LOOKUP*/

DATA param_lookup;
    LENGTH PARAM $100 PARAMCD $8 PARAMN 8;
    INFILE DATALINES DLM='|' DSD;
    INPUT PARAM $ PARAMCD $ PARAMN;
DATALINES;
Word Recall Task|ACITM01|1
Naming Objects And Fingers (Refer To 5 C|ACITM02|2
Delayed Word Recall|ACITM03|3
Commands|ACITM04|4
Constructional Praxis|ACITM05|5
Ideational Praxis|ACITM06|6
Orientation|ACITM07|7
Word Recognition|ACITM08|8
Attention/Visual Search Task|ACITM09|9
Maze Solution|ACITM10|10
Spoken Language Ability|ACITM11|11
Comprehension Of Spoken Language|ACITM12|12
Word Finding Difficulty In Spontaneous S|ACITM13|13
Recall Of Test Instructions|ACITM14|14
Adas-Cog(11) Subscore|ACTOT|15
;
RUN;

PROC SORT DATA = PARAM_LOOKUP;
	BY PARAMCD;
RUN;

PROC SORT DATA = ADAS_STEP_3 OUT = ADAS_QSTESTCD (RENAME = (QSTESTCD = PARAMCD));
	BY QSTESTCD;
RUN;

DATA ADAS_STEP_4;
	MERGE ADAS_QSTESTCD(IN = A) PARAM_LOOKUP(IN = B);
	BY PARAMCD;
	IF A = 1;
RUN;

/*===================================================================================================
									Derivation Chain 1
==================================================================================================*/

/*STEP 5 Derive ABLFL, ADT*/
DATA ADAS_STEP_5;
	SET ADAS_STEP_4;
	LENGTH ABLFL $1;
		ABLFL = QSBLFL;
		ADT = INPUT(QSDTC,YYMMDD10.);
	FORMAT ADT DATE9.;
	DROP QSDTC;
RUN;


/*===================================================================================================
									Derivation Chain 2
==================================================================================================*/
/*STEP 6 Derive ADY*/
DATA ADAS_STEP_6;
	SET ADAS_STEP_5;
	LENGTH ADY 8;
	IF ADT >= TRTSDT THEN ADY = ADT - TRTSDT + 1;
	ELSE IF ADT < TRTSDT AND NOT MISSING(ADT) THEN ADY = ADT - TRTSDT;
RUN;

/*STEP 7 Derive AVAL*/

/*For ACTOT*/
PROC SQL;
SELECT DISTINCT QUOTE(PARAMCD)
INTO :PARAMCD_NAME SEPARATED BY ', '
FROM ADAS_STEP_6
WHERE PARAMCD ^= 'ACTOT'
;
QUIT;

%PUT &PARAMCD_NAME;

PROC SORT DATA = ADAS_STEP_6;
	BY STUDYID USUBJID PARAMCD VISITNUM;
RUN;

/*Add AVAL for NOT SUM*/
DATA ADAS_NOT_SUM_7;
	SET ADAS_STEP_6;
	IF PARAMCD IN (&PARAMCD_NAME) THEN AVAL = QSSTRESN;
RUN;

PROC FREQ DATA = ADAS_NOT_SUM_7;
	TABLES PARAMCD*AVAL/ LIST MISSING;
	WHERE PARAMCD = 'ACTOT';
RUN;

/*Calculate for items SUM*/
DATA ADAS_FOR_ACTOT;
    SET ADAS_STEP_6;
    WHERE PARAMCD IN ('ACITM01','ACITM02','ACITM04','ACITM05','ACITM06','ACITM07',
                      'ACITM08','ACITM11','ACITM12','ACITM13','ACITM14');
    SELECT (PARAMCD);
        WHEN ('ACITM01') _MAX = 10;
        WHEN ('ACITM07') _MAX = 8;
        WHEN ('ACITM08') _MAX = 12;
        OTHERWISE        _MAX = 5;
    END;
    IF NOT MISSING(QSSTRESN) THEN _MAXOBS = _MAX;   /* accumulate the maximum score of answered items only */
    KEEP USUBJID VISITNUM ADT PARAMCD QSSTRESN _MAXOBS;
RUN;

PROC MEANS DATA=ADAS_FOR_ACTOT NOPRINT NWAY;
    CLASS USUBJID VISITNUM ADT;
    VAR QSSTRESN _MAXOBS;
    OUTPUT OUT=_ACTOT (DROP=_TYPE_ _FREQ_)
           N(QSSTRESN)=N_NONMISS  SUM(QSSTRESN)=ITEM_SUM  SUM(_MAXOBS)=MAX_OBS;
RUN;

DATA _ACTOT;
    SET _ACTOT;
    IF 11 - N_NONMISS >= 4 THEN ACTOT_SUM = .;        /* more than 30% of the 11 items missing (4 or more) -> missing */
    ELSE ACTOT_SUM = ITEM_SUM * 70 / MAX_OBS;          /* prorate: item sum x 70 / (70 - maximum score of missing items), SAP 14.2 */
    KEEP USUBJID VISITNUM ADT ACTOT_SUM;
RUN;

/*Merge  _ACTOT and ADAS_NOT_SUM_7 */
PROC SORT DATA = _ACTOT;
	BY USUBJID VISITNUM ADT;
RUN;

PROC SORT DATA = ADAS_NOT_SUM_7;
	BY USUBJID VISITNUM ADT;
RUN;

DATA ADAS_ACTOT_7;
	MERGE ADAS_NOT_SUM_7(IN = A) _ACTOT(IN = B);
	BY USUBJID VISITNUM ADT;
	IF A = 1;
RUN;

DATA ADAS_STEP_7;
	SET ADAS_ACTOT_7;
	IF MISSING(AVAL) AND PARAMCD = 'ACTOT' THEN AVAL = ACTOT_SUM;
	DROP ACTOT_SUM;
RUN;

/*STEP 8 Derive BASE, CHG, PCHG*/
PROC SORT DATA = ADAS_STEP_7;
	BY USUBJID PARAMCD ADT VISITNUM;
RUN;

DATA ADAS_STEP_8;
	SET ADAS_STEP_7;
	BY USUBJID PARAMCD ADT VISITNUM;
	RETAIN BASE_VAL;
	
	IF FIRST.PARAMCD = 1 THEN BASE_VAL = .;
	IF QSBLFL = 'Y' OR VISITNUM = 3 THEN BASE_VAL = AVAL;
	
	BASE = BASE_VAL;
	CHG = AVAL - BASE;
	
	IF NOT MISSING(BASE) AND BASE ^= 0 AND NOT MISSING(CHG) THEN PCHG = 100*(CHG/BASE);
	ELSE IF MISSING(BASE) OR BASE = 0 THEN PCHG = .;
	
	IF ABLFL = 'Y' THEN CALL MISSING(CHG, PCHG);
	
	DROP BASE_VAL;
RUN;

PROC FREQ DATA = ADAS_STEP_8;
	TABLES BASE / MISSING;
RUN;

PROC FREQ DATA = ADAS_STEP_8;
	TABLES BASE * PARAMCD / LIST MISSING;
	WHERE BASE = 0;
RUN;

/*===================================================================================================
									Analysis Window
==================================================================================================*/

/*STEP_9 Derive AVISIT, AVISITN, AWRANGE, AWTARGET, AWTDIFF, AWU*/

DATA ADAS_STEP_9;
    SET ADAS_STEP_8;
    LENGTH AWRANGE $9 AWU $4 AVISIT $16;
	_DAY = ADY;
    IF _DAY <= 1 AND NOT MISSING(_DAY) THEN DO;
        AWRANGE = '<=1';
        AWLO = .;
        AWHI = 1;
        AWTARGET = 1;
        AVISIT = 'Baseline';
        AVISITN = 0;
        AWTDIFF = ABS(_DAY - AWTARGET);
        AWU = 'DAYS';
    END;
    ELSE IF _DAY >= 2 AND _DAY <= 84 THEN DO;
        AWRANGE = '2-84';
        AWLO = 2;
        AWHI = 84;
        AWTARGET = 56;
        AVISIT = 'Week 8';
        AVISITN = 8;
        AWTDIFF = ABS(_DAY - AWTARGET);
        AWU = 'DAYS';
    END;
    ELSE IF _DAY >= 85 AND _DAY<= 140 THEN DO;
        AWRANGE = '85-140';
        AWLO = 85;
        AWHI = 140;
        AWTARGET = 112;
        AVISIT = 'Week 16';
        AVISITN = 16;
        AWTDIFF = ABS(_DAY - AWTARGET);
        AWU = 'DAYS';
    END;
    ELSE IF _DAY > 140 THEN DO;
        AWRANGE = '>140';
        AWLO = 141;
        AWHI = .;
        AWTARGET = 168;
        AVISIT = 'Week 24';
        AVISITN = 24;
        AWTDIFF = ABS(_DAY - AWTARGET);
        AWU = 'DAYS';
    END;
    IF ADY < 0 THEN AWTDIFF = AWTDIFF - 1;
RUN;

/* 1. Check: Visit 3 (randomisation, ADT = TRTSDT) should all have ADY = 1 */
PROC FREQ DATA=ADAS_STEP_9;
    WHERE VISITNUM = 3;
    TABLES _DAY / MISSING;
RUN;

/* 2. Check: records not assigned to any window (expected: none) */
PROC FREQ DATA=ADAS_STEP_9;
    WHERE MISSING(AVISITN);
    TABLES VISITNUM*VISIT*_DAY / LIST MISSING;
RUN;

/* 3. Check: the ADY range of each window lies within AWLO-AWHI */
PROC MEANS DATA=ADAS_STEP_9 N MIN MAX;
    CLASS AVISITN AWRANGE;
    VAR _DAY AWTDIFF;
RUN;

/*==================================================================================================
							Derivation Chain 3
==================================================================================================*/

/*STEP 10 Derive ANL01FL*/
/* 1. Minimum distance to the target day within USUBJID x PARAMCD x AVISITN */
PROC MEANS DATA=ADAS_STEP_9 NOPRINT NWAY;
    WHERE NOT MISSING(AVISITN);
    CLASS USUBJID PARAMCD AVISITN;
    VAR AWTDIFF;
    OUTPUT OUT=MIN_DIFF (DROP=_TYPE_ _FREQ_) MIN=MIN_DIFF;
RUN;

/* 2. Sort by ADY within each group (used to break ties) */
PROC SORT DATA=ADAS_STEP_9 OUT=S9;
    BY USUBJID PARAMCD AVISITN ADY;
RUN;

/* 3. Merge and flag */
DATA ADAS_STEP_10;
    MERGE S9 MIN_DIFF;
    BY USUBJID PARAMCD AVISITN;
    LENGTH ANL01FL $1;
    RETAIN _DONE;

    IF FIRST.AVISITN = 1 THEN _DONE = 0;

    IF NOT MISSING(AVISITN) AND AWTDIFF = MIN_DIFF AND _DONE = 0 THEN DO;
        ANL01FL = 'Y';
        _DONE   = 1;   /* equidistant records: flag only the earlier one (before the target day, SAP 8.2) */
    END;

    DROP _DONE;
RUN;

/*STEP 11 Derive DTYPE*/
/* 11a. LOCF sources: ACTOT, ANL01FL = 'Y', AVAL non-missing; Baseline included (AVISITN >= 0) */
DATA _SRC;
    SET ADAS_STEP_10;
	WHERE PARAMCD = 'ACTOT' AND ANL01FL = 'Y' AND AVISITN >= 0 AND NOT MISSING(AVAL);
RUN;

PROC SORT DATA=_SRC;
    BY USUBJID AVISITN;
RUN;

/* 11b. Shell: every subject with a source record x Week 8/16/24 */
DATA _SHELL;
    SET _SRC (KEEP=USUBJID);
    BY USUBJID;
    IF FIRST.USUBJID THEN DO AVISITN = 8, 16, 24;
        OUTPUT;
    END;
RUN;

/* 11c. Find empty windows and the latest earlier source record */
PROC SQL;
    CREATE TABLE _MISS AS
    SELECT S.USUBJID, S.AVISITN AS TGT_AVISITN
    FROM _SHELL AS S
    WHERE NOT EXISTS (SELECT 1 FROM _SRC AS O
                      WHERE O.USUBJID = S.USUBJID AND O.AVISITN = S.AVISITN);

    CREATE TABLE _LOCF AS
    SELECT O.*, M.TGT_AVISITN
    FROM _MISS AS M, _SRC AS O
    WHERE M.USUBJID = O.USUBJID AND O.AVISITN < M.TGT_AVISITN
    GROUP BY M.USUBJID, M.TGT_AVISITN
    HAVING O.AVISITN = MAX(O.AVISITN);
QUIT;

/* 11d. Move the copied record to the target window and set DTYPE */
DATA _LOCF;
    LENGTH DTYPE $7;
    
    SET _LOCF;
    AVISITN = TGT_AVISITN;
    SELECT (AVISITN);
        WHEN (8)  DO; AVISIT='Week 8';  AWRANGE='2-84';   AWLO=2;   AWHI=84;  AWTARGET=56;  END;
        WHEN (16) DO; AVISIT='Week 16'; AWRANGE='85-140'; AWLO=85;  AWHI=140; AWTARGET=112; END;
        WHEN (24) DO; AVISIT='Week 24'; AWRANGE='>140';   AWLO=141; AWHI=.;   AWTARGET=168; END;
        OTHERWISE;
    END;
    AWTDIFF = ABS(ADY - AWTARGET);
    CALL MISSING(ABLFL);                          /* an LOCF record is not a baseline record */
    CHG = AVAL - BASE;                            /* recompute for the post-baseline record */
    IF NOT MISSING(BASE) AND BASE NE 0 THEN PCHG = 100*(CHG/BASE);
    ELSE PCHG = .;

    DTYPE   = 'LOCF';
    ANL01FL = 'Y';
    DROP TGT_AVISITN;
RUN;

/* 11e. Append the LOCF records */
DATA ADAS_STEP_11;
    LENGTH DTYPE $7;
    SET ADAS_STEP_10 _LOCF;
RUN;

/* 1. Check: DTYPE appears only for ACTOT */
PROC FREQ DATA=ADAS_STEP_11;
    TABLES PARAMCD*DTYPE / LIST MISSING;
RUN;

/* 2. Check (expect 0 rows): more than one ACTOT ANL01FL = 'Y' per subject and window */
PROC SQL;
    SELECT USUBJID, AVISITN, COUNT(*) AS N_Y
    FROM ADAS_STEP_11
    WHERE PARAMCD = 'ACTOT' AND ANL01FL = 'Y'
    GROUP BY USUBJID, AVISITN
    HAVING N_Y > 1;
QUIT;

/* 3. Check (expect 0 rows): an LOCF source date must precede the target window */
PROC PRINT DATA=ADAS_STEP_11;
    WHERE DTYPE = 'LOCF' AND ADY >= AWLO;
    VAR USUBJID AVISITN VISIT ADY AWLO AVAL;
RUN;

PROC FREQ DATA=ADAS_STEP_11;
    WHERE DTYPE = 'LOCF' AND ADT = TRTSDT;   /* LOCF carried from Baseline (expected EFFFL = 'N') */
    TABLES EFFFL / MISSING;
RUN;

PROC FREQ DATA=ADAS_STEP_11;
    WHERE PARAMCD = 'ACTOT' AND ANL01FL = 'Y' AND AVISIT = 'Week 24' AND EFFFL = 'Y';
    TABLES TRTP / MISSING;
RUN;

/* TODO check (expect 0 rows): more than one ABLFL = 'Y' per subject and parameter */

/*==================================================================================================
							 	QC for final
==================================================================================================*/

/*STEP 12 QC: analysis records (EFFFL, ANL01FL, ACTOT, Week 8/16/24) vs reference */
%LET ANLCOND = PARAMCD = 'ACTOT' AND ANL01FL = 'Y' AND AVISITN > 0 AND EFFFL = 'Y';

PROC SORT DATA=ADQSADAS_STD (WHERE=(&ANLCOND)) OUT=_B_ANL; BY USUBJID AVISITN; RUN;
PROC SORT DATA=ADAS_STEP_11 (WHERE=(&ANLCOND)) OUT=_C_ANL; BY USUBJID AVISITN; RUN;

PROC COMPARE BASE=_B_ANL COMPARE=_C_ANL LISTALL;
    ID USUBJID AVISITN;
    VAR AVAL BASE CHG PCHG DTYPE;
RUN;

/*==================================================================================================
                                Final ADQSADAS
==================================================================================================*/

/* STEP 13 Variable order, length, label, format */
DATA ADQSADAS (LABEL = 'ADAS-Cog Analysis');
    ATTRIB
        STUDYID  LENGTH=$12   LABEL='Study Identifier'
        SITEID   LENGTH=$3    LABEL='Study Site Identifier'
        SITEGR1  LENGTH=$3    LABEL='Pooled Site Group 1'
        USUBJID  LENGTH=$11   LABEL='Unique Subject Identifier'
        TRTSDT   LENGTH=8     LABEL='Date of First Exposure to Treatment'  FORMAT=DATE9.
        TRTEDT   LENGTH=8     LABEL='Date of Last Exposure to Treatment'   FORMAT=DATE9.
        TRTP     LENGTH=$20   LABEL='Planned Treatment'
        TRTPN    LENGTH=8     LABEL='Planned Treatment (N)'
        AGE      LENGTH=8     LABEL='Age'
        AGEGR1   LENGTH=$5    LABEL='Pooled Age Group 1'
        AGEGR1N  LENGTH=8     LABEL='Pooled Age Group 1 (N)'
        RACE     LENGTH=$32   LABEL='Race'
        RACEN    LENGTH=8     LABEL='Race (N)'
        SEX      LENGTH=$1    LABEL='Sex'
        ITTFL    LENGTH=$1    LABEL='Intent-to-Treat Population Flag'
        EFFFL    LENGTH=$1    LABEL='Efficacy Population Flag'
        COMP24FL LENGTH=$1    LABEL='Completers of Week 24 Population Flag'
        AVISIT   LENGTH=$16   LABEL='Analysis Visit'
        AVISITN  LENGTH=8     LABEL='Analysis Visit (N)'
        VISIT    LENGTH=$19   LABEL='Visit Name'
        VISITNUM LENGTH=8     LABEL='Visit Number'
        ADY      LENGTH=8     LABEL='Analysis Relative Day'
        ADT      LENGTH=8     LABEL='Analysis Date'                        FORMAT=DATE9.
        PARAM    LENGTH=$100  LABEL='Parameter'
        PARAMCD  LENGTH=$8    LABEL='Parameter Code'
        PARAMN   LENGTH=8     LABEL='Parameter (N)'
        AVAL     LENGTH=8     LABEL='Analysis Value'
        BASE     LENGTH=8     LABEL='Baseline Value'
        CHG      LENGTH=8     LABEL='Change from Baseline'
        PCHG     LENGTH=8     LABEL='Percent Change from Baseline'
        ABLFL    LENGTH=$1    LABEL='Baseline Record Flag'
        ANL01FL  LENGTH=$1    LABEL='Analysis Record Flag 01'
        DTYPE    LENGTH=$7    LABEL='Derivation Type'
        AWRANGE  LENGTH=$9    LABEL='Analysis Window Valid Relative Range'
        AWTARGET LENGTH=8     LABEL='Analysis Window Target'
        AWTDIFF  LENGTH=8     LABEL='Analysis Window Diff from Target'
        AWLO     LENGTH=8     LABEL='Analysis Window Beginning Timepoint'
        AWHI     LENGTH=8     LABEL='Analysis Window Ending Timepoint'
        AWU      LENGTH=$4    LABEL='Analysis Window Unit'
        QSSEQ    LENGTH=8     LABEL='Sequence Number'
    ;
    SET ADAS_STEP_11;
    KEEP STUDYID SITEID SITEGR1 USUBJID TRTSDT TRTEDT TRTP TRTPN AGE AGEGR1 AGEGR1N
         RACE RACEN SEX ITTFL EFFFL COMP24FL AVISIT AVISITN VISIT VISITNUM ADY ADT
         PARAM PARAMCD PARAMN AVAL BASE CHG PCHG ABLFL ANL01FL DTYPE
         AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU QSSEQ;
RUN;

PROC SORT DATA=ADQSADAS;
    BY USUBJID PARAMCD AVISITN DTYPE ADT;
RUN;



/*==================================================================================================
                    QC: structure checks and comparison with the CDISC reference ADQSADAS
==================================================================================================*/
/* 1. Variable order, length, label and format: compare with define.xml */
PROC CONTENTS DATA=ADQSADAS VARNUM;
RUN;

/* 2. Key uniqueness: _DUP expected to have 0 rows */
PROC SORT DATA=ADQSADAS OUT=_KEYCHK NODUPKEY DUPOUT=_DUP;
    BY USUBJID PARAMCD AVISITN DTYPE ADT;
RUN;

/* 3. Final comparison with the reference dataset */
PROC SORT DATA=ADQSADAS_STD OUT=_BAS; BY USUBJID PARAMCD AVISITN DTYPE ADT; RUN;

PROC COMPARE BASE=_BAS COMPARE=ADQSADAS LISTALL;
    ID USUBJID PARAMCD AVISITN DTYPE ADT;
RUN;


/*==================================================================================================
                                Save ADQSADAS
==================================================================================================*/
DATA ADAM.ADQSADAS_V1;
	SET ADQSADAS;
RUN;
