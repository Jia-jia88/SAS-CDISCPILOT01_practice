LIBNAME ADTTE XPORT "&REFPATH/adtte.xpt";
DATA ADAE_V1;
    SET ADAM.ADAE_V1;
RUN;

DATA ADSL_V1;
	SET ADAM.ADSL_V1;
RUN;

DATA ADTTE_STD;
	SET ADTTE.adtte;
RUN;

/*================================================================================================
					 Create the fundamental data structure for ADTTE
=================================================================================================*/

/*STEP 1 Derive ADAE derictly from ADSL */

DATA ADTTE_STEP_1;
	SET ADSL_V1;
	STARTDT = INPUT(RFSTDTC,YYMMDD10.);
	TRTP = TRT01P;
	TRTA = TRT01A;
	TRTAN = TRT01AN;
	
	FORMAT STARTDT DATE9.;
	
	KEEP STUDYID SITEID USUBJID AGE AGEGR1 AGEGR1N RACE RACEN SEX TRTSDT TRTEDT TRTDUR TRTP TRTA TRTAN
	STARTDT RFENDTC RFENDT SAFFL;
RUN;

/*STEP 2 Derive ADAE derictly from ADAE */
DATA ADTTE_STEP_2;
	SET ADAE_V1;
	WHERE AOCC01FL = 'Y' AND CQ01NAM = 'DERMATOLOGIC EVENTS';
	KEEP STUDYID SITEID USUBJID AESEQ TRTEMFL ASTDT;
RUN;

/*STEP 3 Merge STEP 1 and STEP 2 datasets*/
PROC SORT DATA = ADTTE_STEP_1;
	BY STUDYID SITEID USUBJID;
RUN;

PROC SORT DATA = ADTTE_STEP_2;
	BY STUDYID SITEID USUBJID;
RUN;

DATA ADTTE_STEP_3;
	MERGE ADTTE_STEP_1(IN = A) ADTTE_STEP_2(IN = B);
	BY STUDYID SITEID USUBJID;
	IF A = 1;
RUN;
/*================================================================================================
=================================================================================================*/


/*===============================================================================================
								Derivation Chian 1
=================================================================================================*/

/*STEP 4 Derive PARAMCD PARAM*/
DATA ADTTE_STEP_4;
	SET ADTTE_STEP_3;
	PARAM = 'Time to First Dermatologic Event';
	PARAMCD = 'TTDE';
RUN;

/*STEP 5 Derive CNSR*/
DATA ADTTE_STEP_5;
	SET ADTTE_STEP_4;
	IF TRTEMFL = 'Y' THEN CNSR = 0;
	ELSE CNSR = 1;
RUN;

/*===============================================================================================
								Derivation Chian 2
=================================================================================================*/
/*STEP 6 Derive ADT, AVAL, SRCDOM, SRCVAR, SRCSEQ*/
DATA ADTTE_STEP_6;
	SET ADTTE_STEP_5;
	LENGTH SRCDOM $4 SRCVAR $6;
	IF NOT MISSING(ASTDT) AND ASTDT >= TRTSDT THEN DO;
		ADT = ASTDT;
		SRCDOM = 'ADAE';
		SRCVAR = 'ASTDT';
		SRCSEQ = AESEQ;
	END;
	ELSE DO;
		ADT = RFENDT;
		SRCDOM = 'ADSL';
		SRCVAR = 'RFENDT';
		SRCSEQ = .;
	END;
	
	FORMAT ADT DATE9.;
	AVAL = ADT - STARTDT + 1;
RUN;

/*STEP 7 Derive EVNTDESC*/
DATA ADTTE_STEP_7;
	SET ADTTE_STEP_6;
	IF CNSR = 0 THEN EVNTDESC = 'Dematologic Event Occured';
	ELSE IF CNSR = 1 THEN EVNTDESC = 'Study Completion Date';
RUN;

/*STEP 8*/
DATA ADTTE_STEP_8;
	ATTRIB
		STUDYID  LENGTH = $12  LABEL = 'Study Identifier'
		SITEID   LENGTH = $3   LABEL = 'Study Site Identifier'
		USUBJID  LENGTH = $11  LABEL = 'Unique Subject Identifier'
		AGE      LENGTH = 8    LABEL = 'Age'
		AGEGR1   LENGTH = $5   LABEL = 'Pooled Age Group 1'
		AGEGR1N  LENGTH = 8    LABEL = 'Pooled Age Group 1 (N)'
		RACE     LENGTH = $32  LABEL = 'Race'
		RACEN    LENGTH = 8    LABEL = 'Race (N)'
		SEX      LENGTH = $1   LABEL = 'Sex'
		TRTSDT   LENGTH = 8    LABEL = 'Date of First Exposure to Treatment'  FORMAT = DATE9.
		TRTEDT   LENGTH = 8    LABEL = 'Date of Last Exposure to Treatment'   FORMAT = DATE9.
		TRTDUR   LENGTH = 8    LABEL = 'Duration of treatment (days)'
		TRTP     LENGTH = $20  LABEL = 'Planned Treatment'
		TRTA     LENGTH = $20  LABEL = 'Actual Treatment'
		TRTAN    LENGTH = 8    LABEL = 'Actual Treatment (N)'
		PARAM    LENGTH = $100 LABEL = 'Parameter Description'
		PARAMCD  LENGTH = $8   LABEL = 'Parameter Code'
		AVAL     LENGTH = 8    LABEL = 'Analysis Value'
		STARTDT  LENGTH = 8    LABEL = 'Time to Event Origin Date for Subject' FORMAT = DATE9.
		ADT      LENGTH = 8    LABEL = 'Analysis Date'                         FORMAT = DATE9.
		CNSR     LENGTH = 8    LABEL = 'Censor'
		EVNTDESC LENGTH = $25  LABEL = 'Event or Censoring Description'
		SRCDOM   LENGTH = $4   LABEL = 'Source Domain'
		SRCVAR   LENGTH = $6   LABEL = 'Source Variable'
		SRCSEQ   LENGTH = 8    LABEL = 'Source Sequence Number'
		SAFFL    LENGTH = $1   LABEL = 'Safety Population Flag'
	;

	SET ADTTE_STEP_7;

	KEEP STUDYID SITEID USUBJID AGE AGEGR1 AGEGR1N RACE RACEN SEX
	     TRTSDT TRTEDT TRTDUR TRTP TRTA TRTAN
	     PARAM PARAMCD AVAL STARTDT ADT CNSR EVNTDESC
	     SRCDOM SRCVAR SRCSEQ SAFFL;
RUN;

/*=============================================================================================
								QC
==============================================================================================*/

/*STEP 9 QC*/
PROC SORT DATA = ADTTE_STD;
	BY STUDYID USUBJID PARAMCD;
RUN;

PROC SORT DATA = ADTTE_STEP_8;
	BY STUDYID USUBJID PARAMCD;
RUN;

PROC COMPARE BASE = ADTTE_STD COMPARE = ADTTE_STEP_8;
	ID STUDYID USUBJID PARAMCD;
RUN;

DATA ADAM.ADTTE_V1;
	SET ADTTE_STEP_8;
RUN;
