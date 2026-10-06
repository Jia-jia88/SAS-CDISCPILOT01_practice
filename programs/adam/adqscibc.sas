LIBNAME QSSDTM XPORT "&SDTMPATH/qs.xpt";
LIBNAME ADQSCIBC XPORT "&REFPATH/adqscibc.xpt";

DATA ADSL_V1;
    SET ADAM.ADSL_V1;
RUN;

DATA QS_SDTM;
	SET QSSDTM.qs;
RUN;

DATA ADQSCIBC_STD;
	SET ADQSCIBC.adqscibc;
RUN;

/*============================================================================================
							Derive Chain 0
==============================================================================================*/

/*STEP 1 Derive ADSL directly*/
DATA ADSL_STEP_1;
	SET ADSL_V1;
	TRTP = TRT01P;
	TRTPN = TRT01PN;
	KEEP STUDYID USUBJID SITEID SITEGR1 USUBJID TRTSDT TRTEDT TRTP TRTPN
	AGE AGEGR1 AGEGR1N RACE RACEN SEX ITTFL EFFFL COMP24FL;
RUN;

/*STEP 2 Derive QS directly*/

PROC SQL;
SELECT *
FROM Dictionary.columns
WHERE libname = 'WORK'
AND memname = 'QS_SDTM'
;
QUIT;

DATA QS_STEP_2;
	SET QS_SDTM;
	WHERE  QSTESTCD = 'CIBIC';
	KEEP STUDYID USUBJID QSTESTCD QSTEST QSSTRESN QSDTC QSBLFL VISITNUM VISIT VISITDY QSSEQ QSDRVFL; 
RUN;

/*STEP 3 Merge QS and ADSL*/
PROC SORT DATA = QS_STEP_2;
	BY STUDYID USUBJID;
RUN;

PROC SORT DATA = ADSL_STEP_1;
	BY STUDYID USUBJID;
RUN;

DATA CIBC_STEP_3;
	MERGE QS_STEP_2(IN = A) ADSL_STEP_1(IN = B);
	BY STUDYID USUBJID;
	IF A = 1;
RUN;

/*============================================================================================
							Derive Chain 1
==============================================================================================*/
/*STEP 4 PARAM_LOOKUP*/

DATA param_lookup;
    LENGTH QSTESTCD $8 PARAMCD $8 PARAM $100 PARAMN 8;
    QSTESTCD = 'CIBIC';
    PARAMCD  = 'CIBICVAL';
    PARAM    = 'CIBIC Score';
    PARAMN   = 1;
RUN;

PROC SORT DATA = PARAM_LOOKUP;
	BY QSTESTCD;
RUN;

PROC SORT DATA = CIBC_STEP_3;
	BY QSTESTCD;
RUN;

DATA CIBC_STEP_4;
    MERGE CIBC_STEP_3 (IN = A) PARAM_LOOKUP(IN = B);
    BY QSTESTCD;
    IF A = 1;
RUN;

/*STEP 5 Derive ADT, ADY, AVAL*/

DATA CIBC_STEP_5 ;
	SET CIBC_STEP_4;
	ADT = INPUT(QSDTC, YYMMDD10.);
	FORMAT ADT DATE9.;
	
	IF ADT >= TRTSDT THEN ADY = ADT - TRTSDT + 1;
	ELSE IF ADT < TRTSDT AND NOT MISSING(ADT) THEN ADY = ADT - TRTSDT;
	
	AVAL = QSSTRESN;
RUN;

/*============================================================================================
							Derive Chain 2
==============================================================================================*/

/*STEP 6 Derive AVISIT, AVISITN, AWRANGE, AWTARGET, AWTDIFF, AWLO, AWHI, AWU*/
DATA CIBC_STEP_6;
	SET CIBC_STEP_5;
	LENGTH AVISIT $16  AWRANGE $9 AWU $4;
	
	IF ADY <= 1 AND NOT MISSING(ADY) THEN DO;
		AWRANGE = '<=1'; AWTARGET = 1; AWTDIFF = ABS(ADY-AWTARGET); AWLO = .; AWHI = 1; AWU = 'DAYS';
		AVISIT = 'Baseline'; AVISITN = 3;
	END;
	
	ELSE IF 2 <= ADY AND ADY <= 84 THEN DO;
		AWRANGE = '2-84'; AWTARGET = 56; AWTDIFF = ABS(ADY-AWTARGET); AWLO = 2; AWHI = 84; AWU = 'DAYS';
		AVISIT = 'Week 8'; AVISITN = 8;
	END;
	
	ELSE IF 85 <= ADY AND ADY <= 140 THEN DO;
		AWRANGE = '85-140'; AWTARGET = 112; AWTDIFF = ABS(ADY-AWTARGET); AWLO = 85; AWHI = 140; AWU = 'DAYS';
		AVISIT = 'Week 16'; AVISITN = 16;
	END;
		
	ELSE IF ADY > 140 THEN DO;
		AWRANGE = '>140'; AWTARGET = 168; AWTDIFF = ABS(ADY-AWTARGET); AWLO = 141; AWHI = .; AWU = 'DAYS';
		AVISIT = 'Week 24'; AVISITN = 24;		
	END;
RUN;

/*STEP 7 Derive ANL01FL*/
PROC SORT DATA = CIBC_STEP_6;
	BY USUBJID PARAMCD AVISITN;
RUN;

PROC MEANS DATA = CIBC_STEP_6 NOPRINT NWAY;
	CLASS USUBJID PARAMCD AVISITN;
	VAR AWTDIFF;
	OUTPUT OUT = SUMMARY_TARGET;
RUN;

DATA MIN_TARGET;
	SET SUMMARY_TARGET;
	IF _STAT_ = 'MIN';
	ANL01FL = 'Y';
	DROP _FREQ_ _TYPE_ _STAT_;
RUN;

PROC SORT DATA = MIN_TARGET;
	BY USUBJID PARAMCD AVISITN AWTDIFF;
RUN;

PROC SORT DATA = CIBC_STEP_6;
	BY USUBJID PARAMCD AVISITN AWTDIFF;
RUN;

DATA CIBC_STEP_7;
	MERGE MIN_TARGET(IN = A) CIBC_STEP_6(IN = B);
	BY USUBJID PARAMCD AVISITN AWTDIFF;
	IF B = 1;
RUN;

/*STEP 8 Derive DTYPE*/
DATA WINDOW_LOOKUP;
    LENGTH AVISIT $16 AWRANGE $9 AWU $4;
    AVISITN= 8; AVISIT='Week 8';  AWRANGE='2-84';   AWTARGET= 56; AWLO=  2; AWHI= 84; AWU='DAYS'; OUTPUT;
    AVISITN=16; AVISIT='Week 16'; AWRANGE='85-140'; AWTARGET=112; AWLO= 85; AWHI=140; AWU='DAYS'; OUTPUT;
    AVISITN=24; AVISIT='Week 24'; AWRANGE='>140';   AWTARGET=168; AWLO=141; AWHI=  .; AWU='DAYS'; OUTPUT;
RUN;

PROC SQL;
CREATE TABLE _ALL AS 
SELECT DISTINCT A.USUBJID, B.AVISITN, B.AVISIT, B.AWLO, B.AWHI, B.AWTARGET, B.AWRANGE, B.AWU
FROM (SELECT DISTINCT USUBJID FROM CIBC_STEP_7) AS A
CROSS JOIN WINDOW_LOOKUP AS B
;
CREATE TABLE IMPUTE_DTYPE AS SELECT USUBJID, AVISITN, AVISIT, AWLO, AWHI, AWTARGET, AWRANGE, AWU
FROM _ALL
EXCEPT ALL
SELECT USUBJID, AVISITN, AVISIT, AWLO, AWHI, AWTARGET, AWRANGE, AWU
FROM CIBC_STEP_7
;
SELECT COUNT(*)
FROM IMPUTE_DTYPE
;
SELECT COUNT(*)
FROM _ALL
;
QUIT;

DATA IMPUTE_DTYPE_LOCF;
	SET IMPUTE_DTYPE;
	DTYPE = 'LOCF';
RUN;

DATA CIBC_IMPUTE;
	SET CIBC_STEP_7 IMPUTE_DTYPE_LOCF;
RUN;

PROC SORT DATA = CIBC_IMPUTE;
	BY USUBJID AVISITN AVISIT;
RUN;

DATA CIBC_STEP_8_IMPUTE;
	SET CIBC_IMPUTE;
	BY USUBJID AVISITN AVISIT;
	LENGTH _VISIT $19;
	RETAIN val_impute _ADT _ADY _VISITNUM _VISIT _VISITDY _QSSEQ;

	IF FIRST.USUBJID THEN DO;
    	val_impute = .; _ADT = .; _ADY = .;
    	_VISITNUM = .; _VISIT = ''; _VISITDY = .; _QSSEQ = .;
	END;

	IF ANL01FL = 'Y' AND NOT MISSING(AVAL) THEN DO;      /* 更新鏈條 */
    	val_impute = AVAL;
    	_ADT = ADT; _ADY = ADY;
    	_VISITNUM = VISITNUM; _VISIT = VISIT; _VISITDY = VISITDY; _QSSEQ = QSSEQ;
	END;

	IF DTYPE = 'LOCF' THEN DO;                           /* 填補 */
    	AVAL = val_impute;
   	 	ADT = _ADT; ADY = _ADY;
    	VISITNUM = _VISITNUM; VISIT = _VISIT; VISITDY = _VISITDY; QSSEQ = _QSSEQ;
    	AWTDIFF = ABS(ADY - AWTARGET);                   /* 用來源 ADY、目標 AWTARGET 重算 */
		ANL01FL = 'Y';
	END;
	DROP val_impute _ADT _ADY _VISITNUM _VISIT _VISITDY _QSSEQ;
/* ① 剔除那一行還是沒加，補在 STEP_8_IMPUTE 的最後 */
    IF NOT (DTYPE = 'LOCF' AND MISSING(AVAL));
    DROP val_impute _ADT _ADY _VISITNUM _VISIT _VISITDY _QSSEQ;
RUN;

/* ② 補回 ADSL 與參數欄位 */
PROC SORT DATA = CIBC_STEP_8_IMPUTE; BY USUBJID; RUN;
PROC SORT DATA = ADSL_STEP_1;        BY USUBJID; RUN;

DATA CIBC_STEP_8;
    MERGE CIBC_STEP_8_IMPUTE (IN = B
              DROP = STUDYID SITEID SITEGR1 TRTSDT TRTEDT TRTP TRTPN
                     AGE AGEGR1 AGEGR1N RACE RACEN SEX ITTFL EFFFL COMP24FL)
          ADSL_STEP_1;
    BY USUBJID;
    IF B = 1;

    PARAMCD = 'CIBICVAL';        /* 只有一個參數，直接賦值比 merge 省事 */
    PARAM   = 'CIBIC Score';
    PARAMN  = 1;
RUN;

PROC SORT DATA = CIBC_STEP_8; BY USUBJID PARAMCD AVISITN ADY; RUN;


/*STEP 9 RETAIN and KEEP needed variables*/
DATA ADQSCIBC_FINAL (LABEL = 'CIBIC+ Analysis');
    ATTRIB
        STUDYID  LENGTH=$12   LABEL='Study Identifier'
        SITEID   LENGTH=$3    LABEL='Study Site Identifier'
        SITEGR1  LENGTH=$3    LABEL='Pooled Site Group 1'
        USUBJID  LENGTH=$11   LABEL='Unique Subject Identifier'
        TRTSDT   LENGTH=8     LABEL='Date of First Exposure to Treatment'  FORMAT=DATE9.
        TRTEDT   LENGTH=8     LABEL='Date of Last Exposure to Treatment'   FORMAT=DATE9.
        TRTP     LENGTH=$20   LABEL='Planned Treatment'
        TRTPN    LENGTH=8     LABEL='Planned Treatment (N)'				   FORMAT = 8.
        AGE      LENGTH=8     LABEL='Age'								   FORMAT = 8.
        AGEGR1   LENGTH=$5    LABEL='Pooled Age Group 1'                  
        AGEGR1N  LENGTH=8     LABEL='Pooled Age Group 1 (N)'               FORMAT = 8.
        RACE     LENGTH=$32   LABEL='Race'
        RACEN    LENGTH=8     LABEL='Race (N)'                             FORMAT = 8.
        SEX      LENGTH=$1    LABEL='Sex'
        ITTFL    LENGTH=$1    LABEL='Intent-to-Treat Population Flag'
        EFFFL    LENGTH=$1    LABEL='Efficacy Population Flag'
        COMP24FL LENGTH=$1    LABEL='Completers of Week 24 Population Flag'
        AVISIT   LENGTH=$16   LABEL='Analysis Visit'
        AVISITN  LENGTH=8     LABEL='Analysis Visit (N)'                   FORMAT = 8.1
        VISIT    LENGTH=$19   LABEL='Visit Name'
        VISITNUM LENGTH=8     LABEL='Visit Number'
        ADY      LENGTH=8     LABEL='Analysis Relative Day'                FORMAT = 8.
        ADT      LENGTH=8     LABEL='Analysis Date'                        FORMAT=DATE9.
        PARAMCD  LENGTH=$8    LABEL='Parameter Code'
        PARAM    LENGTH=$100  LABEL='Parameter'                            
        PARAMN   LENGTH=8     LABEL='Parameter (N)'                        FORMAT = 8.
        AVAL     LENGTH=8     LABEL='Analysis Value'
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
    SET CIBC_STEP_8;

    KEEP STUDYID SITEID SITEGR1 USUBJID TRTSDT TRTEDT TRTP TRTPN
         AGE AGEGR1 AGEGR1N RACE RACEN SEX ITTFL EFFFL COMP24FL
         AVISIT AVISITN VISIT VISITNUM ADY ADT
         PARAMCD PARAM PARAMN AVAL ANL01FL DTYPE
         AWRANGE AWTARGET AWTDIFF AWLO AWHI AWU QSSEQ;
RUN;

PROC SORT DATA = ADQSCIBC_FINAL;
    BY USUBJID PARAMCD AVISITN ADY;
RUN;
/*=============================================================================================
							 		QC step
===============================================================================================*/

/*STEP 10 Compare*/
PROC SORT DATA = ADQSCIBC_FINAL;
	BY STUDYID USUBJID PARAMCD AVISIT DTYPE;
RUN;

PROC SORT DATA = ADQSCIBC_STD;
	BY STUDYID USUBJID PARAMCD AVISIT DTYPE;
RUN;

PROC COMPARE BASE = ADQSCIBC_STD COMPARE = adqscibc_final;
	ID STUDYID USUBJID PARAMCD AVISIT DTYPE;
RUN;


DATA ADAM.ADQSCIBC_V1;
	SET ADQSCIBC_FINAL;
RUN;
