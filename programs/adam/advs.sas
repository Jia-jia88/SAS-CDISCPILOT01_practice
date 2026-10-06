/*==========================================================================
  Program   : advs.sas
  Study     : CDISCPILOT01
  Purpose   : Derive ADVS (Vital Signs Analysis Dataset, BDS), including
              End of Treatment pseudo-records (AVISITN = 99) for SYSBP,
              DIABP, PULSE and WEIGHT.
  Input     : ADAM.ADSL_V1, SDTM VS
              Reference ADVS (advs.xpt) - used for QC comparison
  Output    : ADAM.ADVS_V1
  Spec      : CDISCPILOT01 define.xml (ADVS) and SAP section 11.6
  Run after : setup.sas, adsl.sas
==========================================================================*/

LIBNAME ADVS XPORT "&REFPATH/advs.xpt";
LIBNAME VSSDTM XPORT "&SDTMPATH/vs.xpt";

DATA ADSL_V1;
	SET ADAM.ADSL_V1;
RUN;

DATA ADVS_STD;
	SET ADVS.advs;
RUN;

DATA VS_SDTM;
	SET VSSDTM.VS;
RUN;

/*=============================================================================================
							Create the fundamental datatable
===============================================================================================*/
/*STEP 1 Derive variables directly from ADSL*/
DATA ADVS_STEP_1;
	SET ADSL_V1;
	TRTP = TRT01P;
	TRTPN = TRT01PN;
	TRTA = TRT01A;
	TRTAN = TRT01AN;
	KEEP STUDYID SITEID USUBJID AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL TRTSDT TRTEDT
	TRTP TRTPN TRTA TRTAN;
RUN;

/*STEP 2 Derive variables directly from VS*/
DATA ADVS_STEP_2;
	SET VS_SDTM;
	KEEP STUDYID USUBJID VSDTC VSDY VSTPT VSTPTNUM VISIT VISITNUM VSSTRESN VSSEQ VSBLFL VSTESTCD;
RUN;


/*STEP 3 PARAM_LOOKUP*/
DATA param_lookup;
    length PARAMCD $8 PARAM $100 PARAMN 8;
    infile datalines dlm='|' dsd truncover;
    input PARAMCD  $ PARAM $ PARAMN;
datalines;
SYSBP|Systolic Blood Pressure (mmHg)|1
DIABP|Diastolic Blood Pressure (mmHg)|2
PULSE|Pulse Rate (BEATS/MIN)|3
WEIGHT|Weight (kg)|4
HEIGHT|Height (cm)|5
TEMP|Temperature (C)|6
;
RUN;

/*STEP 4 Merge STEP 1 and STEP 2 and STEP 3*/
PROC SORT DATA = ADVS_STEP_1;
	BY STUDYID USUBJID;
RUN;

PROC SORT DATA = ADVS_STEP_2;
	BY STUDYID USUBJID;
RUN;

DATA _VS_ADSL;
	MERGE ADVS_STEP_2 (IN = A) ADVS_STEP_1(IN = B);
	BY STUDYID USUBJID;
	IF A = 1;
RUN;

PROC SORT DATA = _VS_ADSL OUT = _VS_ADSL_MERGE (RENAME = (VSTESTCD = PARAMCD));
	BY VSTESTCD;
RUN;

PROC SORT DATA = PARAM_LOOKUP;
	BY PARAMCD;
RUN;

DATA ADVS_STEP_4;
	LENGTH PARAMCD $8;
	MERGE _VS_ADSL_MERGE(IN = A) PARAM_LOOKUP(IN = B);
	BY PARAMCD;
	IF A = 1;
RUN;

/*===============================================================================================
								Derivation Chain 0
=================================================================================================*/

/*STEP 5 Derive AVISIT, AVISITN, ADT, ADY, ATPTN, ATPT*/
DATA ADVS_STEP_5;
	SET ADVS_STEP_4;
	LENGTH AVISIT $16 AVISITN 8 ATPT $30 ATPTN 8 ADT 8 ADY 8;
	
	ADT = INPUT(SUBSTR(VSDTC,1,10), YYMMDD10.);
	FORMAT ADT DATE9.;
	
	ADY = VSDY;
	
	ATPT = VSTPT;
	ATPTN = VSTPTNUM;


	IF VISIT IN ('AMBUL ECG PLACEMENT', 'AMBUL ECG REMOVAL', 'RETRIEVAL','SCREENING 1','SCREENING 2', 'UNSCHEDULED 3.1')
				THEN AVISIT = '';
	ELSE AVISIT_UPPER = VISIT;
	
	IF AVISIT_UPPER = 'BASELINE' THEN DO;
		AVISIT = 'Baseline';
		AVISITN = 0;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 2' THEN DO;
		AVISIT = 'Week 2';
		AVISITN = 2;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 4' THEN DO;
		AVISIT = 'Week 4';
		AVISITN = 4;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 6' THEN DO;
		AVISIT = 'Week 6';
		AVISITN = 6;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 8' THEN DO;
		AVISIT = 'Week 8';
		AVISITN = 8;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 12' THEN DO;
		AVISIT = 'Week 12';
		AVISITN = 12;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 16' THEN DO;
		AVISIT = 'Week 16';
		AVISITN = 16;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 20' THEN DO;
		AVISIT = 'Week 20';
		AVISITN = 20;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 24' THEN DO;
		AVISIT = 'Week 24';
		AVISITN = 24;
	END;
	ELSE IF AVISIT_UPPER = 'WEEK 26' THEN DO;
		AVISIT = 'Week 26';
		AVISITN = 26;
	END;
	
RUN;

/*STEP 6 Derive AVAL, BASE, CHG, PCHG, ABLFL*/
PROC SORT DATA = ADVS_STEP_5;
    BY STUDYID USUBJID PARAMCD ATPTN DESCENDING VSBLFL ADT VSSEQ;
RUN;


DATA ADVS_STEP_6;
	SET ADVS_STEP_5;
	RETAIN BASE_val;
	BY STUDYID USUBJID PARAMCD ATPTN;
	
	AVAL = VSSTRESN;
	ABLFL = VSBLFL;
	
	IF FIRST.ATPTN = 1 THEN BASE_val = .;
	IF VSBLFL = 'Y' THEN BASE_val = VSSTRESN;
	BASE = BASE_val;
	
	IF MISSING(BASE) THEN CHG = .;
	ELSE CHG = AVAL - BASE;
	
	IF MISSING(BASE) OR MISSING(CHG) OR BASE = 0 THEN PCHG = .;
	ELSE PCHG = 100*(CHG/BASE);
	
	DROP BASE_val;
RUN;

/*STEP 7 Derive ANL01FL*/
DATA ADVS_STEP_7;
    SET ADVS_STEP_6;
    LENGTH ANL01FL $1;
    IF NOT MISSING(AVISIT) THEN ANL01FL = 'Y';
RUN;

/*================================================================================================================
									Derive for the End of Treatments
==================================================================================================================*/
/*STEP 8 Derive EOT*/

PROC SORT DATA = ADVS_STEP_7 OUT = FOR_EOT;
    BY STUDYID USUBJID PARAMCD ATPTN AVISITN ADT VSSEQ;
    WHERE 0 < AVISITN <= 24;
RUN;

DATA EOT_FL;
    SET FOR_EOT;
    BY STUDYID USUBJID PARAMCD ATPTN AVISITN ADT VSSEQ;
    IF LAST.ATPTN = 1 AND PARAMCD ^= 'TEMP' THEN DO;
    	EOT_FL = 'Y';
    	AVISIT = 'End of Treatment';
    	AVISITN = 99;
    	ABLFL   = '';
    END;
    IF EOT_FL = 'Y';
    DROP EOT_FL;
RUN;



DATA ADVS_STEP_8;
	SET EOT_FL ADVS_STEP_7;
RUN;

/*===============================================================================================
								 	Final ADVS
=================================================================================================*/

/*STEP 9 Final attributes, variable order, and sort*/
DATA ADVS_STEP_9 (LABEL = "Vital Signs Analysis Dataset");
    ATTRIB
        STUDYID  LENGTH = $12   LABEL = "Study Identifier"
        SITEID   LENGTH = $3    LABEL = "Study Site Identifier"
        USUBJID  LENGTH = $11   LABEL = "Unique Subject Identifier"
        AGE      LENGTH = 8     LABEL = "Age"
        AGEGR1   LENGTH = $5    LABEL = "Pooled Age Group 1"
        AGEGR1N  LENGTH = 8     LABEL = "Pooled Age Group 1 (N)"
        RACE     LENGTH = $32   LABEL = "Race"
        RACEN    LENGTH = 8     LABEL = "Race (N)"
        SEX      LENGTH = $1    LABEL = "Sex"
        SAFFL    LENGTH = $1    LABEL = "Safety Population Flag"
        TRTSDT   LENGTH = 8     LABEL = "Date of First Exposure to Treatment"
        TRTEDT   LENGTH = 8     LABEL = "Date of Last Exposure to Treatment"
        TRTP     LENGTH = $20   LABEL = "Planned Treatment"
        TRTPN    LENGTH = 8     LABEL = "Planned Treatment (N)"
        TRTA     LENGTH = $20   LABEL = "Actual Treatment"
        TRTAN    LENGTH = 8     LABEL = "Actual Treatment (N)"
        PARAMCD  LENGTH = $8    LABEL = "Parameter Code"
        PARAM    LENGTH = $100  LABEL = "Parameter"
        PARAMN   LENGTH = 8     LABEL = "Parameter Number"
        ADT      LENGTH = 8     LABEL = "Analysis Date"
        ADY      LENGTH = 8     LABEL = "Analysis Relative Day"
        ATPTN    LENGTH = 8     LABEL = "Analysis Timepoint (N)"
        ATPT     LENGTH = $30   LABEL = "Analysis Timepoint"
        AVISIT   LENGTH = $16   LABEL = "Analysis Visit"
        AVISITN  LENGTH = 8     LABEL = "Analysis Visit (N)"
        AVAL     LENGTH = 8     LABEL = "Analysis Value"
        BASE     LENGTH = 8     LABEL = "Baseline Value"
        CHG      LENGTH = 8     LABEL = "Change from Baseline"
        PCHG     LENGTH = 8     LABEL = "Percent Change from Baseline"
        VISITNUM LENGTH = 8     LABEL = "Visit Number"
        VISIT    LENGTH = $19   LABEL = "Visit Name"
        VSSEQ    LENGTH = 8     LABEL = "Sequence Number"
        ANL01FL  LENGTH = $1    LABEL = "Analysis Record Flag 01"
        ABLFL    LENGTH = $1    LABEL = "Baseline Record Flag"
    ;

    SET ADVS_STEP_8;

    FORMAT _ALL_;
    INFORMAT _ALL_;
    FORMAT TRTSDT TRTEDT ADT DATE9.;

    KEEP STUDYID SITEID USUBJID AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL
         TRTSDT TRTEDT TRTP TRTPN TRTA TRTAN
         PARAMCD PARAM PARAMN ADT ADY ATPTN ATPT AVISIT AVISITN
         AVAL BASE CHG PCHG VISITNUM VISIT VSSEQ ANL01FL ABLFL;
RUN;

/*===============================================================================================
						QC: compare with the CDISC reference ADVS
		EOT records: this program follows SAP 11.6 (last visit on or before Week 24);
		the reference dataset also uses Week 26, so single-sided EOT records are expected.
=================================================================================================*/
PROC FREQ DATA = ADVS_STD;
	TABLES VISITNUM*VISIT*AVISITN*AVISIT/LIST MISSING;
	WHERE AVISITN = 99;
RUN;

PROC FREQ DATA = ADVS_STEP_9;
	TABLES VISITNUM*VISIT*AVISITN*AVISIT/LIST MISSING;
	WHERE AVISITN = 99;
RUN;

/*STEP 10 Compare*/
PROC SORT DATA = ADVS_STEP_9;
	BY STUDYID USUBJID VSSEQ AVISITN;
RUN;

PROC SORT DATA = ADVS_STD;
	BY STUDYID USUBJID VSSEQ AVISITN;
RUN;

PROC COMPARE BASE = ADVS_STD COMPARE = ADVS_STEP_9;
	ID STUDYID USUBJID VSSEQ AVISITN;
RUN;



DATA ADAM.ADVS_V1;
	SET ADVS_STEP_9;
RUN;
