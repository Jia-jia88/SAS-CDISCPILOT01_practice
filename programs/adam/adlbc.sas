LIBNAME ADAM "/home/u63793342/sasuser.v94";
LIBNAME LBSDTM XPORT "/home/u63793342/sasuser.v94/lb.xpt";
LIBNAME ADLBC XPORT "/home/u63793342/sasuser.v94/adlbc.xpt";

DATA ADSL_V1;
    SET ADAM.ADSL_V1;
RUN;

DATA lb_sdtm;
	SET LBSDTM.lb;
RUN;

DATA adlbc_std;
	SET ADLBC.adlbc;
RUN;

DATA adlbc_std_WITHOUT_EOT;
	SET ADLBC.adlbc;
	WHERE AVISITN ^= 99;
RUN;

PROC SQL;
SELECT
    STRIP(name)||'='||QUOTE(TRIM(label))
INTO :LABEL_ADLBC SEPARATED BY ' '
FROM Dictionary.columns
WHERE libname = 'WORK'
AND memname = 'ADLBC_STD'
;
QUIT;

%PUT &LABEL_ADLBC;



/*===================================================================================================
						Derivation Chain 0
===================================================================================================*/

/*Step 1 Derive variables from ADSL directly*/
DATA ADSL_STEP_1;
	LENGTH RACE $32;
	SET ADSL_V1;
	TRTP = TRT01P;
	TRTPN = TRT01PN;
	TRTA = TRT01A;
	TRTAN = TRT01AN;
	KEEP STUDYID SUBJID USUBJID TRTP TRTPN TRTA TRTAN TRTSDT TRTEDT 
	AGE AGEGR1 AGEGR1N RACE RACEN SEX SAFFL COMP24FL DSRAEFL SAFFL;
RUN;

/*Step 2 Derive variables from LB directly*/

DATA LB_STEP_2;
	LENGTH LBTESTCD $8;
	LENGTH LBNRIND $8;
	SET lb_sdtm;
	WHERE LBCAT = 'CHEMISTRY'
	  AND VISIT NOT IN ('AMBUL ECG REMOVAL', 'RETRIEVAL');   /* 非實驗室評估訪視 */
	KEEP STUDYID USUBJID LBSEQ LBTESTCD LBTEST LBCAT LBSTRESN LBSTRESC
	     LBSTNRLO LBSTNRHI LBNRIND LBBLFL VISITNUM VISIT LBDY LBDTC;
RUN;


/*Step 3 Create the tables for PARAM*/
DATA param_lookup;
    LENGTH PARAM $100 PARAMCD $8 PARCAT1 $5;
    INFILE DATALINES DLM='|' DSD;
    INPUT PARAM $ PARAMCD $ PARAMN PARCAT1 $;
DATALINES;
Sodium (mmol/L)|SODIUM|18|CHEM
Potassium (mmol/L)|K|19|CHEM
Chloride (mmol/L)|CL|20|CHEM
Bilirubin (umol/L)|BILI|21|CHEM
Alkaline Phosphatase (U/L)|ALP|22|CHEM
Gamma Glutamyl Transferase (U/L)|GGT|23|CHEM
Alanine Aminotransferase (U/L)|ALT|24|CHEM
Aspartate Aminotransferase (U/L)|AST|25|CHEM
Blood Urea Nitrogen (mmol/L)|BUN|26|CHEM
Creatinine (umol/L)|CREAT|27|CHEM
Urate (umol/L)|URATE|28|CHEM
Phosphate (mmol/L)|PHOS|29|CHEM
Calcium (mmol/L)|CA|30|CHEM
Glucose (mmol/L)|GLUC|31|CHEM
Protein (g/L)|PROT|32|CHEM
Albumin (g/L)|ALB|33|CHEM
Cholesterol (mmol/L)|CHOL|34|CHEM
Creatine Kinase (U/L)|CK|35|CHEM
Sodium (mmol/L) change from previous visit, relative to normal range|_SODIUM|118|CHEM
Potassium (mmol/L) change from previous visit, relative to normal range|_K|119|CHEM
Chloride (mmol/L) change from previous visit, relative to normal range|_CL|120|CHEM
Bilirubin (umol/L) change from previous visit, relative to normal range|_BILI|121|CHEM
Alkaline Phosphatase (U/L) change from previous visit, relative to normal range|_ALP|122|CHEM
Gamma Glutamyl Transferase (U/L) change from previous visit, relative to normal range|_GGT|123|CHEM
Alanine Aminotransferase (U/L) change from previous visit, relative to normal range|_ALT|124|CHEM
Aspartate Aminotransferase (U/L) change from previous visit, relative to normal range|_AST|125|CHEM
Blood Urea Nitrogen (mmol/L) change from previous visit, relative to normal range|_BUN|126|CHEM
Creatinine (umol/L) change from previous visit, relative to normal range|_CREAT|127|CHEM
Urate (umol/L) change from previous visit, relative to normal range|_URATE|128|CHEM
Phosphate (mmol/L) change from previous visit, relative to normal range|_PHOS|129|CHEM
Calcium (mmol/L) change from previous visit, relative to normal range|_CA|130|CHEM
Glucose (mmol/L) change from previous visit, relative to normal range|_GLUC|131|CHEM
Protein (g/L) change from previous visit, relative to normal range|_PROT|132|CHEM
Albumin (g/L) change from previous visit, relative to normal range|_ALB|133|CHEM
Cholesterol (mmol/L) change from previous visit, relative to normal range|_CHOL|134|CHEM
Creatine Kinase (U/L) change from previous visit, relative to normal range|_CK|135|CHEM
;
RUN;

/*Step 4 Merge param and LB*/

/*Step 4A Merge param and original data*/
PROC SORT DATA = param_lookup;
	BY PARAMCD;
RUN;


PROC SORT DATA = LB_STEP_2 OUT = LB_ORI_FOR_MERGE (RENAME = (LBTESTCD = PARAMCD));
	BY LBTESTCD;
RUN;


DATA LB_STEP_4A_O;
	MERGE LB_ORI_FOR_MERGE(IN = A) PARAM_LOOKUP(IN = B);
	BY PARAMCD;
	IF A = 1;
RUN;

/*Step 4B Merge param and change data*/

DATA LB_CHG_FOR_MERGE;
	SET LB_STEP_2;
	PARAMCD = STRIP('_'||LBTESTCD);
	DROP LBTESTCD;
RUN;

PROC SORT DATA = PARAM_LOOKUP;
	BY PARAMCD;
RUN;

PROC SORT DATA = LB_CHG_FOR_MERGE;
	BY PARAMCD;
RUN;

DATA LB_STEP_4B_C;
	MERGE LB_CHG_FOR_MERGE (IN = A) PARAM_LOOKUP(IN = B);
	BY PARAMCD;
	IF A = 1;
RUN;

/*===================================================================================================
						Derivation Chian 1
===================================================================================================*/
/*Step 5A Derive ADY, ADT, A1LO, A1HI, AVAL for original */
DATA LB_STEP_5A_O;
	SET LB_STEP_4A_O;
	AVAL = LBSTRESN;
	ADY = LBDY;
	A1LO = LBSTNRLO;
	A1HI = LBSTNRHI;
	ADT = INPUT(SUBSTR(LBDTC, 1, 10), YYMMDD10.);
	FORMAT ADT DATE9.;
	FORMAT ADY 3.;
	DROP LBDY LBSTNRLO LBSTNRHI LBDTC;
RUN;

/*Step 5b Derive ADY, ADT, A1LO, A1HI, AVAL for change*/
PROC SORT DATA = LB_STEP_4B_C;
	BY USUBJID PARAMCD VISITNUM;
RUN;
DATA LB_STEP_5B_C;
	SET LB_STEP_4B_C;
	BY USUBJID PARAMCD VISITNUM;

	RETAIN preval;
	IF FIRST.PARAMCD THEN preval = .;
	LBSTRESN_PRIOR = preval;

	IF VISITNUM NE INT(VISITNUM) THEN AVAL = .;        /* 未排程訪視不算 AVAL */
	ELSE IF LBBLFL = 'Y' THEN AVAL = .;
	ELSE AVAL = ROUND((LBSTRESN - LBSTRESN_PRIOR)/(0.5*(LBSTNRHI-LBSTNRLO)), 0.1);

	IF VISITNUM = INT(VISITNUM) THEN preval = LBSTRESN;  /* 只有排程訪視更新 prior */

	ADY = LBDY;
	A1LO = .;
	A1HI = .;
	ADT = INPUT(SUBSTR(LBDTC, 1, 10), YYMMDD10.);
	FORMAT ADT DATE9. ADY 3.;
	DROP LBDY LBDTC preval LBSTRESN_PRIOR;
RUN;

/*===================================================================================================
						Derivation Chian 2
===================================================================================================*/

/*Step 6A Derive AVISIT AVISITN ABLFL*/

DATA LB_STEP_6A_O;
	SET LB_STEP_5A_O;
	LENGTH AVISIT $16;
	IF VISITNUM = 1 THEN DO;
		AVISIT = 'Baseline';
		AVISITN = 0;
	END;
	ELSE IF VISITNUM = 4 THEN DO;
		AVISIT = 'Week 2';
		AVISITN = 2;
	END;
	ELSE IF VISITNUM = 5 THEN DO;
		AVISIT = 'Week 4';
		AVISITN = 4;
	END;
	ELSE IF VISITNUM = 7 THEN DO;
		AVISIT = 'Week 6';
		AVISITN = 6;
	END;
	ELSE IF VISITNUM = 8 THEN DO;
		AVISIT = 'Week 8';
		AVISITN = 8;
	END;
	ELSE IF VISITNUM = 9 THEN DO;
		AVISIT = 'Week 12';
		AVISITN = 12;
	END;
	ELSE IF VISITNUM = 10 THEN DO;
		AVISIT = 'Week 16';
		AVISITN = 16;
	END;
	ELSE IF VISITNUM = 11 THEN DO;
		AVISIT = 'Week 20';
		AVISITN = 20;
	END;
	ELSE IF VISITNUM = 12 THEN DO;
		AVISIT = 'Week 24';
		AVISITN = 24;
	END;
	ELSE IF VISITNUM = 13 THEN DO;
		AVISIT = 'Week 26';
		AVISITN = 26;
	END;
	IF VISITNUM = 1 THEN ABLFL = 'Y';
RUN;

/*Check 6A*/
PROC FREQ DATA = LB_STEP_6A_O;
	TABLES VISITNUM*VISIT*AVISITN*AVISIT*ABLFL /LIST MISSING;
RUN;

/*Step 6B Derive AVISIT AVISITN ABLFL*/
DATA LB_STEP_6B_C;
	SET LB_STEP_5B_C;
	
	IF VISITNUM = 1 THEN DO;
		AVISIT = 'Baseline';
		AVISITN = 0;
	END;
	ELSE IF VISITNUM = 4 THEN DO;
		AVISIT = 'Week 2';
		AVISITN = 2;
	END;
	ELSE IF VISITNUM = 5 THEN DO;
		AVISIT = 'Week 4';
		AVISITN = 4;
	END;
	ELSE IF VISITNUM = 7 THEN DO;
		AVISIT = 'Week 6';
		AVISITN = 6;
	END;
	ELSE IF VISITNUM = 8 THEN DO;
		AVISIT = 'Week 8';
		AVISITN = 8;
	END;
	ELSE IF VISITNUM = 9 THEN DO;
		AVISIT = 'Week 12';
		AVISITN = 12;
	END;
	ELSE IF VISITNUM = 10 THEN DO;
		AVISIT = 'Week 16';
		AVISITN = 16;
	END;
	ELSE IF VISITNUM = 11 THEN DO;
		AVISIT = 'Week 20';
		AVISITN = 20;
	END;
	ELSE IF VISITNUM = 12 THEN DO;
		AVISIT = 'Week 24';
		AVISITN = 24;
	END;
	ELSE IF VISITNUM = 13 THEN DO;
		AVISIT = 'Week 26';
		AVISITN = 26;
	END;
	ABLFL = '';
RUN;


/*===================================================================================================
						Derivation Chian 2
===================================================================================================*

/*Step 7A Derive BASE CHG R2A1LO R2A1HI BR2A1LO BR2A1HI */

PROC SORT DATA = LB_STEP_6A_O;
	BY USUBJID PARAMCD VISITNUM;
RUN;

DATA LB_STEP_7A_O;
	SET LB_STEP_6A_O;
	BY USUBJID PARAMCD VISITNUM;

	RETAIN BASE BR2A1LO BR2A1HI;

	IF FIRST.PARAMCD THEN DO;      /* 重置跟 ABLFL 無關,是進新群組就要做 */
		BASE    = .;
		BR2A1LO = .;
		BR2A1HI = .;
	END;

	IF ABLFL = 'Y' THEN DO;        /* 這裡只負責「填值」 */
		BASE    = LBSTRESN;
		BR2A1LO = AVAL / A1LO;
		BR2A1HI = AVAL / A1HI;
	END;

	IF ABLFL = 'Y' THEN CHG = .;   /* baseline 沒有「相對於 baseline 的變化」 */
	ELSE CHG = AVAL - BASE;

	R2A1LO = AVAL / A1LO;
	R2A1HI = AVAL / A1HI;
RUN;

/*Step 7B Derive BASE CHG R2A1LO R2A1HI BR2A1LO BR2A1HI */
DATA LB_STEP_7B_C;
	SET LB_STEP_6B_C;
	BY USUBJID PARAMCD VISITNUM;
	BASE = .;
	CHG = .;
	R2A1LO = .;
	R2A1HI = .;
	BR2A1LO = .;
	BR2A1HI = .;
RUN;

/*Step 8A Derive ALBTRVAL ANL01FL*/
DATA LB_STEP_8A_ALBTRVAL;
	SET LB_STEP_7A_O;
	ALBTRVAL = MAX((1.5*A1HI)-LBSTRESN , LBSTRESN-(0.5*A1LO));
RUN;

PROC SORT DATA = LB_STEP_8A_ALBTRVAL  OUT = FOR_ANL01FL (KEEP = USUBJID PARAMCD VISITNUM ALBTRVAL);
	BY USUBJID PARAMCD DESCENDING ALBTRVAL VISITNUM;
	WHERE VISITNUM IN (4,5,7,8,9,10,11,12);
RUN;

DATA DERIVE_ANL01FL;
	SET FOR_ANL01FL;
	BY USUBJID PARAMCD DESCENDING ALBTRVAL VISITNUM;
	IF FIRST.PARAMCD AND NOT MISSING(ALBTRVAL) THEN ANL01FL = 'Y';
RUN;

PROC SORT DATA = DERIVE_ANL01FL;
	BY USUBJID PARAMCD VISITNUM;
RUN;

PROC SORT DATA = LB_STEP_8A_ALBTRVAL;
	BY USUBJID PARAMCD VISITNUM;
RUN;

DATA LB_STEP_8A_O;
	MERGE LB_STEP_8A_ALBTRVAL(IN = A) DERIVE_ANL01FL(IN = B);
	BY USUBJID PARAMCD VISITNUM;
	IF A = 1;
RUN;



/*Step 8B Derive ALBTRVAL ANL01FL*/
DATA LB_STEP_8B_ALBTRVAL;
	SET LB_STEP_7B_C;
	ALBTRVAL = MAX((1.5*LBSTNRHI)-LBSTRESN , LBSTRESN-(0.5*LBSTNRLO));
	ABS_AVAL = ABS(AVAL);
RUN;

PROC SORT DATA = LB_STEP_8B_ALBTRVAL
          OUT  = FOR_ANL01FL_C (KEEP = USUBJID PARAMCD VISITNUM ABS_AVAL);
	BY USUBJID PARAMCD DESCENDING ABS_AVAL VISITNUM;
	WHERE VISITNUM IN (4,5,7,8,9,10,11,12);
RUN;

DATA DERIVE_ANL01FL_C;
	SET FOR_ANL01FL_C;
	BY USUBJID PARAMCD DESCENDING ABS_AVAL VISITNUM;
	IF FIRST.PARAMCD AND NOT MISSING(ABS_AVAL) THEN ANL01FL = 'Y';
	DROP ABS_AVAL;
RUN;

PROC SORT DATA = DERIVE_ANL01FL_C;
	BY USUBJID PARAMCD VISITNUM;
RUN;

PROC SORT DATA = LB_STEP_8B_ALBTRVAL;
	BY USUBJID PARAMCD VISITNUM;
RUN;

DATA LB_STEP_8B_C;
	MERGE LB_STEP_8B_ALBTRVAL(IN = A) DERIVE_ANL01FL_C(IN = B);
	BY USUBJID PARAMCD VISITNUM;
	IF A = 1;
RUN;


/*Step 9A Derive ANRIND BNRIND*/
DATA FOR_BNRIND;
	SET LB_STEP_8A_O;

	/* AVAL 維持缺失,只有判斷 ANRIND 時改用 censored 的數值 */
	IF MISSING(LBSTRESN) AND NOT MISSING(LBSTRESC)
	   THEN IND_VAL = INPUT(COMPRESS(LBSTRESC, '<>='), 12.);
	   ELSE IND_VAL = AVAL;

	IF MISSING(IND_VAL) THEN ANRIND = '';
	ELSE IF IND_VAL < (0.5*A1LO) THEN ANRIND = 'L';
	ELSE IF IND_VAL > (1.5*A1HI) THEN ANRIND = 'H';
	ELSE ANRIND = 'N';

	IF ABLFL = 'Y' THEN BNRIND_FL = ANRIND;
	DROP IND_VAL;
RUN;

PROC SORT DATA = FOR_BNRIND OUT = BRIND_FL (KEEP = USUBJID PARAMCD BNRIND_FL) NODUPKEY;
	BY USUBJID PARAMCD;
	WHERE BNRIND_FL NE '';
RUN;

PROC SORT DATA = FOR_BNRIND;
	BY USUBJID PARAMCD;
RUN;

DATA LB_STEP_9A_O;
	MERGE FOR_BNRIND (IN=A DROP=BNRIND_FL) BRIND_FL (IN=B);
	BY USUBJID PARAMCD;
	IF A;
	BNRIND = BNRIND_FL;
	DROP BNRIND_FL;
RUN;


/*Step 9B Derive ANRIND BNRIND*/
DATA LB_STEP_9B_C;
	SET LB_STEP_8B_C;

	IF MISSING(AVAL) OR LBBLFL = 'Y' THEN ANRIND = '';
	ELSE IF AVAL < -1 THEN ANRIND = 'L';
	ELSE IF AVAL >  1 THEN ANRIND = 'H';
	ELSE ANRIND = 'N';

	BNRIND = '';
RUN;

/*Step 10A Derive AENTMTFL*/
PROC SORT DATA = LB_STEP_9A_O OUT = AENTMTFL_FL (KEEP = USUBJID PARAMCD VISITNUM);
	BY USUBJID PARAMCD DESCENDING VISITNUM;
	WHERE VISITNUM IN (4,5,7,8,9,10,11,12);
RUN;

DATA AENTMTFL_FOR_MERGE;
	SET AENTMTFL_FL;
	BY USUBJID PARAMCD DESCENDING VISITNUM;
	IF FIRST.PARAMCD = 1 THEN AENTMTFL = 'Y'; 
RUN;

PROC SORT DATA = AENTMTFL_FOR_MERGE;
	BY USUBJID PARAMCD VISITNUM;
RUN;

PROC SORT DATA = LB_STEP_9A_O;
	BY USUBJID PARAMCD VISITNUM;
RUN;

DATA LB_STEP_10A_O;
	MERGE LB_STEP_9A_O(IN = A) AENTMTFL_FOR_MERGE(IN = B);
	BY USUBJID PARAMCD VISITNUM;
	IF NOT B THEN AENTMTFL = ' '; 
	IF A = 1;
RUN;


/*Step 10B Derive AENTMTFL*/

PROC SORT DATA = lb_step_9b_c OUT = FOR_AENTMTFL_C (KEEP = USUBJID PARAMCD VISITNUM);
	BY USUBJID PARAMCD VISITNUM;
	WHERE VISITNUM IN (4,5,7,8,9,10,11,12);
RUN;

DATA AENTMTFL_MERGE_C;
	SET FOR_AENTMTFL_C ;
	BY USUBJID PARAMCD VISITNUM;
	IF LAST.PARAMCD = 1 THEN AENTMTFL = 'Y';
	ELSE AENTMTFL = '';
RUN;

PROC FREQ DATA = AENTMTFL_MERGE_C;
	TABLES VISITNUM*AENTMTFL /LIST MISSING;
RUN;

PROC SORT DATA = AENTMTFL_MERGE_C;
	BY USUBJID PARAMCD VISITNUM;
RUN;

PROC SORT DATA = lb_step_9b_c;
	BY USUBJID PARAMCD VISITNUM;
RUN;

DATA LB_STEP_10B_C;
	MERGE LB_STEP_9B_C (IN = A) AENTMTFL_MERGE_C(IN = B);
	BY USUBJID PARAMCD VISITNUM;
	IF A = 1;
	DROP LBSTNRHI LBSTNRLO;
RUN;

/*=================================================================================================
							STACK Original data and Change data
==================================================================================================*/
/*Step 11 Stack two dataset*/
PROC SQL;
SELECT name
FROM Dictionary.columns
WHERE libname = 'WORK'
AND memname = 'LB_STEP_10B_C'
EXCEPT
SELECT name
FROM Dictionary.columns
WHERE libname = 'WORK'
AND memname = 'LB_STEP_10A_O'
;
QUIT;


DATA LB_STEP_11_STACK;
	SET LB_STEP_10A_O LB_STEP_10B_C;
RUN;



/*=================================================================================================
								MERGE ADSL and LB
==================================================================================================*/
/*Step 12 Merge ADSL and LB*/
PROC SORT DATA = ADSL_STEP_1;
	BY STUDYID USUBJID;
RUN;

PROC SORT DATA = LB_STEP_11_STACK;
	BY STUDYID USUBJID;
RUN;

DATA ADLBC_STEP_12_MERGE;
	RETAIN
	STUDYID SUBJID USUBJID TRTP TRTPN TRTA TRTAN TRTSDT TRTEDT AGE AGEGR1 AGEGR1N RACE RACEN SEX COMP24FL
	DSRAEFL SAFFL AVISIT AVISITN ADY ADT VISIT VISITNUM PARAM PARAMCD PARAMN PARCAT1 AVAL BASE CHG
	A1LO A1HI R2A1LO R2A1HI BR2A1LO BR2A1HI ANL01FL ALBTRVAL ANRIND BNRIND ABLFL AENTMTFL LBSEQ LBNRIND
	LBSTRESN
	;

	MERGE ADSL_STEP_1 (IN = A) LB_STEP_11_STACK(IN = B);
	BY STUDYID USUBJID;

	LABEL &LABEL_ADLBC;
	
	KEEP
	STUDYID SUBJID USUBJID TRTP TRTPN TRTA TRTAN TRTSDT TRTEDT AGE AGEGR1 AGEGR1N RACE RACEN SEX COMP24FL
	DSRAEFL SAFFL AVISIT AVISITN ADY ADT VISIT VISITNUM PARAM PARAMCD PARAMN PARCAT1 AVAL BASE CHG
	A1LO A1HI R2A1LO R2A1HI BR2A1LO BR2A1HI ANL01FL ALBTRVAL ANRIND BNRIND ABLFL AENTMTFL LBSEQ LBNRIND
	LBSTRESN
	;
RUN;

PROC CONTENTS DATA = ADLBC_STD;
RUN;

PROC CONTENTS DATA = ADLBC_STEP_12_MERGE;
RUN;

/*=================================================================================================
								Pseudo_Record
==================================================================================================*/
DATA pseudo_record_for_EOT;
	SET ADLBC_STEP_12_MERGE;
	LENGTH AVISIT $16;
	WHERE AENTMTFL = 'Y';
	AVISIT = 'End of Treatment';
	AVISITN = 99;
RUN;

DATA ADLBC_FINAL;
	SET ADLBC_STEP_12_MERGE pseudo_record_for_EOT;
	AVISIT = RIGHT(AVISIT);
RUN;

/*=================================================================================================
								Compare ADLBC final
==================================================================================================*/

PROC SORT DATA = ADLBC_FINAL;
	BY USUBJID PARAMCD VISITNUM AVISITN;
RUN;

PROC SORT DATA = ADLBC_STD;
	BY USUBJID PARAMCD VISITNUM AVISITN;
RUN;

PROC COMPARE BASE = ADLBC_STD COMPARE = adlbc_final;
	ID USUBJID PARAMCD VISITNUM AVISITN;
RUN;


/*===============================================================================================
									ADLBC_V1
================================================================================================*/

LIBNAME ADAM "/home/u63793342/sasuser.v94";
DATA ADAM.ADLBC_V1;
    SET ADLBC_FINAL;
RUN;


/*=================================================================================================
									QC CHECK
==================================================================================================*/



PROC SQL;
SELECT USUBJID, LBTESTCD, VISITNUM, LBSTRESN, LBSTRESC, LBORRES,
       LBNRIND, LBSTNRLO, LBSTNRHI
FROM lb_sdtm
WHERE LBCAT = 'CHEMISTRY'
  AND ( (USUBJID='01-701-1115' AND LBTESTCD='GLUC' AND VISITNUM=5)
     OR (USUBJID='01-701-1363' AND LBTESTCD='BILI' AND VISITNUM=12)
     OR (USUBJID='01-704-1323' AND LBTESTCD='BILI' AND VISITNUM=5)
     OR (USUBJID='01-705-1031' AND LBTESTCD='BILI' AND VISITNUM=12)
     OR (USUBJID='01-705-1393' AND LBTESTCD='BILI' AND VISITNUM=4)
     OR (USUBJID='01-711-1036' AND LBTESTCD='BILI' AND VISITNUM=12) )
ORDER BY USUBJID, LBTESTCD, VISITNUM;
QUIT;

PROC PRINT DATA = ADLBC_FINAL NOOBS;
	WHERE USUBJID = '01-704-1323'
	  AND PARAMCD IN ('BILI','_BILI','ALP','_ALP','K','_K','PHOS','_PHOS');
	VAR PARAMCD VISITNUM AVISITN LBSTRESN AVAL ALBTRVAL ANL01FL;
RUN;


PROC SORT DATA = ADLBC_FINAL OUT = _F; BY USUBJID PARAMCD VISITNUM AVISITN; RUN;
PROC SORT DATA = ADLBC_STD   OUT = _S; BY USUBJID PARAMCD VISITNUM AVISITN; RUN;

DATA EXTRA_72;
	MERGE _F (IN=F)
	      _S (IN=S KEEP=USUBJID PARAMCD VISITNUM AVISITN);
	BY USUBJID PARAMCD VISITNUM AVISITN;
	IF F AND NOT S;
	KEEP USUBJID PARAMCD VISITNUM AVISITN AVISIT AENTMTFL AVAL;
RUN;

PROC FREQ DATA = EXTRA_72;
	TABLES USUBJID*AVISITN / LIST MISSING;
RUN;

/* 先看這兩位的未排程訪視長什麼樣 */
PROC PRINT DATA = EXTRA_72 NOOBS;
	WHERE PARAMCD IN ('ALB','_ALB');
	VAR USUBJID PARAMCD VISITNUM AVISITN AVISIT ADY ADT AVAL AENTMTFL;
RUN;

/* 再看這兩位在原始 LB 的完整訪視序列,以及治療期間 */
PROC SQL;
SELECT DISTINCT a.USUBJID, a.VISITNUM, a.VISIT, a.LBDY,
       b.TRTSDT FORMAT=DATE9., b.TRTEDT FORMAT=DATE9.
FROM lb_sdtm AS a
LEFT JOIN ADSL_V1 AS b ON a.USUBJID = b.USUBJID
WHERE a.LBCAT = 'CHEMISTRY'
  AND a.USUBJID IN ('01-704-1025','01-715-1107')
ORDER BY a.USUBJID, a.VISITNUM;
QUIT;

PROC FREQ DATA = lb_sdtm;
	WHERE LBCAT = 'CHEMISTRY';
	TABLES VISITNUM*VISIT / LIST MISSING;
	TITLE '來源 LB 的所有訪視';
RUN;

PROC FREQ DATA = ADLBC_STD;
	TABLES VISITNUM*VISIT / LIST MISSING;
	TITLE '參考資料集實際納入的訪視';
RUN;
TITLE;



LIBNAME ADAM "/home/u63793342/sasuser.v94";

DATA ADAM.ADLBC_V1;
	SET LB_STEP_14;
RUN;