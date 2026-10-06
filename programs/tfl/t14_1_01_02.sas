LIBNAME ADAM "/home/u63793342/sasuser.v94";

/*=================================================================================================
							Table 14-1.01 Summary of Populations
===================================================================================================*/

/*================================Basic Check===========================*/
PROC FREQ DATA = ADAM.ADSL_V1;
	TABLES (ITTFL SAFFL EFFFL COMP24FL DISCONFL)*TRT01PN/ LIST MISSING;
RUN;
/*======================================================================*/

/* STEP 1. TRT01PN = 99 */
DATA ADSL_REPORT_1;
	SET ADAM.ADSL_V1;
	OUTPUT;
	TRT01PN = 99;          /* Total：Shell 有、Define 沒有 */
	OUTPUT;
	KEEP ITTFL SAFFL EFFFL COMP24FL DISCONFL TRT01PN DCREASCD;
RUN;

/* STEP 2 Summarize the Flags by PROC FREQ*/
PROC FREQ DATA = ADSL_REPORT_1 NOPRINT;
  	TABLES ITTFL*TRT01PN / LIST MISSING OUT = ITT_TABLE(KEEP = ITTFL TRT01PN COUNT);
  	WHERE ITTFL = 'Y';
RUN;

PROC FREQ DATA = ADSL_REPORT_1 NOPRINT;
	TABLES SAFFL*TRT01PN / LIST MISSING OUT = SAFF_TABLE(KEEP = SAFFL TRT01PN COUNT);
	WHERE SAFFL = 'Y';
RUN;

PROC FREQ DATA = ADSL_REPORT_1 NOPRINT;
	TABLES EFFFL*TRT01PN / LIST MISSING OUT = EFFF_TABLE(KEEP = EFFFL TRT01PN COUNT);
	WHERE EFFFL = 'Y';
RUN;

PROC FREQ DATA = ADSL_REPORT_1 NOPRINT;
	TABLES COMP24FL*TRT01PN / LIST MISSING OUT = COMP24_TABLE(KEEP = COMP24FL TRT01PN COUNT);
	WHERE COMP24FL = 'Y';
RUN;

PROC FREQ DATA = ADSL_REPORT_1 NOPRINT;
	TABLES DISCONFL*TRT01PN / LIST MISSING OUT = DISCONFL_TABLE(KEEP = DISCONFL TRT01PN COUNT);
	WHERE DISCONFL = '';
RUN;

/* STEP 3 TRANSPOSE tables*/

PROC TRANSPOSE DATA = ITT_TABLE OUT = ITT_TRANS (DROP = _NAME_ _LABEL_);
	VAR COUNT;
	ID TRT01PN;
	BY ITTFL;
RUN;

PROC TRANSPOSE DATA = SAFF_TABLE OUT = SAFF_TRANS (DROP = _NAME_ _LABEL_);
	VAR COUNT;
	ID TRT01PN;
	BY SAFFL;
RUN;

PROC TRANSPOSE DATA = EFFF_TABLE OUT = EFFF_TRANS (DROP = _NAME_ _LABEL_);
	VAR COUNT;
	ID TRT01PN;
	BY EFFFL;
RUN;

PROC TRANSPOSE DATA = COMP24_TABLE OUT = COMP24_TRANS (DROP = _NAME_ _LABEL_);
	VAR COUNT;
	ID TRT01PN;
	BY COMP24FL;
RUN;

PROC TRANSPOSE DATA = DISCONFL_TABLE OUT = DISCONFL_TRANS (DROP = _NAME_ _LABEL_);
	VAR COUNT;
	ID TRT01PN;
	BY DISCONFL;
RUN;

/* STEP 4 STACK all TRANSPOSE tables*/


DATA SUMMARY_TABLE;
	LENGTH Population $30;
	SET ITT_TRANS(IN = A) SAFF_TRANS(IN = B) EFFF_TRANS(IN = C) COMP24_TRANS(IN = D) 
	DISCONFL_TRANS(IN = E);
	RETAIN N_0 N_54 N_81 N_99;
	
	IF A THEN DO;
		N_0 = '0'n;
		N_54 = '54'n;
		N_81 = '81'n;
		N_99 = '99'n;
	END;
	
	IF A THEN Population = 'Intent-To-Treat (ITT)';
	ELSE IF B THEN Population = 'Safety';
	ELSE IF C THEN Population = 'Efficacy';
	ELSE IF D THEN Population = 'Completer Week 24' ;
	ELSE IF E THEN Population = 'Complete Study';

	
	DROP ITTFL SAFFL EFFFL COMP24FL DISCONFL;
	RENAME '0'n = Placebo_N '54'n = Low_N '81'n =High_N '99'n = Total_N;
RUN;

PROC PRINT DATA = SUMMARY_TABLE;
RUN;

/* STEP 5 Caculate Percent*/

DATA PCT_TABLE;
	SET SUMMARY_TABLE;
	Place_pct = 100*(Placebo_N / N_0);
	Low_pct = 100*(Low_N / N_54);
	High_pct = 100*(High_N / N_81);
	Total_pct = 100*(Total_N / N_99);
	
	Placebo = STRIP(PUT(Placebo_N, 3.))||' ('||STRIP(PUT(Place_pct, 3.)||'%')||')';
	Low = STRIP(PUT(Low_N, 3.))||' ('||STRIP(PUT(Low_pct, 3.)||'%')||')';
	High = STRIP(PUT(High_N, 3.))||' ('||STRIP(PUT(High_pct, 3.)||'%')||')';
	Total = STRIP(PUT(Total_N, 3.))||' ('||STRIP(PUT(Total_pct, 3.)||'%')||')';
	
	KEEP Population Placebo Low High Total;
RUN;


/* STEP 6 Abstract the Number of N*/
DATA _NULL_;
  SET SUMMARY_TABLE(OBS = 1);
  CALL SYMPUTX('N0',  N_0);
  CALL SYMPUTX('N54', N_54);
  CALL SYMPUTX('N81', N_81);
  CALL SYMPUTX('N99', N_99);
RUN;

%PUT &N0 &N54 &N81 &N99;

/* STEP 7 Finish table*/

PROC REPORT DATA = PCT_TABLE NOWINDOWS SPLIT = '|';
  COLUMN Population Placebo Low High Total;
  DEFINE Population / ORDER ORDER = DATA 'Population' LEFT;
  DEFINE Placebo    / DISPLAY "Placebo|(N=&N0)"               CENTER;
  DEFINE Low        / DISPLAY "Xanomeline|Low Dose|(N=&N54)"  CENTER;
  DEFINE High       / DISPLAY "Xanomeline|High Dose|(N=&N81)" CENTER;
  DEFINE Total      / DISPLAY "Total|(N=&N99)"                CENTER;
RUN;

/* STEP 8 Finish table*/
OPTIONS NODATE NONUMBER ORIENTATION = LANDSCAPE;
ODS ESCAPECHAR = '^';
ODS RTF FILE = "/home/u63793342/sasuser.v94/t14_1_01_v2.rtf" STYLE = JOURNAL;

TITLE1 J=L 'CDISC SDTM/ADaM Pilot Project' J=R 'CDISCPILOT01';
TITLE2 J=L 'Protocol: CDISCPILOT01' J=R 'Page ^{thispage} of ^{lastpage}';
TITLE3 J=L 'Population: All Subjects';
TITLE4 BOLD 'Table 14-1.01';
TITLE5 'Summary of Populations';

FOOTNOTE1 J=L 'NOTE: N in column headers represents number of subjects entered in study (i.e., signed informed consent).';
FOOTNOTE2 J=L 'The ITT population includes all subjects randomized. The Safety population includes all randomized subjects';
FOOTNOTE3 J=L 'known to have taken at least one dose of randomized study drug. The Efficacy population includes all subjects';
FOOTNOTE4 J=L 'in the safety population who also have at least one post-baseline ADAS-Cog and CIBIC+ assessment.';

PROC REPORT DATA = PCT_TABLE NOWINDOWS SPLIT = '|';
  COLUMN Population Placebo Low High Total;
  DEFINE Population / ORDER ORDER = DATA 'Population' LEFT;
  DEFINE Placebo    / DISPLAY "Placebo|(N=&N0)"               CENTER;
  DEFINE Low        / DISPLAY "Xanomeline|Low Dose|(N=&N54)"  CENTER;
  DEFINE High       / DISPLAY "Xanomeline|High Dose|(N=&N81)" CENTER;
  DEFINE Total      / DISPLAY "Total|(N=&N99)"                CENTER;
RUN;

ODS RTF CLOSE;
TITLE;
FOOTNOTE;
/*================================================================================================*/


/*=================================================================================================
		Table_14-1.02 Summary of Demographic and Baseline Characteristics (ITT population)
===================================================================================================*/

/*================================Basic Check===================================*/
proc freq data = ADAM.ADSL_V1;
  table COMP24FL*TRT01P/chisq fisher exact;
run;

proc freq data = ADAM.ADSL_V1;
  where COMP24FL="N";
  table DCREASCD* TRT01P/ chisq fisher exact;
run;
/*==================================================================================*/

/*============================ Completion Status ==================================*/

/*STEP 1 Create the pivot for COMP24FL*/
DATA REPORT_2_COMP;
	SET ADSL_REPORT_1;
	WHERE ITTFL = 'Y'; 
	KEEP COMP24FL TRT01PN;
RUN;

PROC FREQ DATA = REPORT_2_COMP NOPRINT;
	TABLES COMP24FL * TRT01PN / LIST MISSING OUT = COMP24FL_TABLE(KEEP = COMP24FL TRT01PN COUNT);
RUN;

PROC PRINT DATA = COMP24FL_TABLE;
RUN;

/*STEP 2 TRANSPOSE*/
PROC TRANSPOSE DATA = COMP24FL_TABLE OUT = COMP24FL_TRANS (DROP = _NAME_ _LABEL_);
	ID TRT01PN;
	VAR COUNT;
	BY COMP24FL;
RUN;

PROC PRINT DATA = COMP24FL_TRANS;
RUN;

/*STEP 3 Calculate Percent*/

DATA COMP_STATUS;
  LENGTH STATUS $40;
  SET COMP24FL_TRANS END = LAST;
  
  IF COMP24FL = 'Y' THEN DO; ORD = 1; STATUS = 'Completed Week 24'; END;
  ELSE IF COMP24FL = 'N' THEN DO; ORD = 2; STATUS = 'Early Termination (prior to Week 24)'; END;
  OUTPUT;
  
  IF LAST THEN DO;
	STATUS = 'Missing';
	'0'N = 0; '54'N = 0; '81'N = 0; '99'N = 0; ORD = 3;
	OUTPUT;
  END;
  DROP COMP24FL;
RUN;

DATA COMP_PCT;
	SET COMP_STATUS;
  PCT_0 = 100*('0'N / &N0);
  PCT_54 = 100*('54'N / &N54);
  PCT_81 = 100*('81'N / &N81);
  PCT_99 = 100*('99'N / &N99);
  
  Placebo = '0'N||' ('||PUT(PCT_0,3.)||'%)';
  Low = '54'N||' ('||PUT(PCT_54,3.)||'%)';
  High = '81'N||' ('||PUT(PCT_81,3.)||'%)';
  Total = '99'N||' ('||PUT(PCT_99,3.)||'%)';
  BLK = 1;
  KEEP STATUS Placebo Low High Total BLK ORD;
RUN;


%PUT &N0 &N54 &N81 &N99;

/*==================================================================================*/

/*============================ Early Termination ====================================*/

proc freq data = ADAM.ADSL_V1;
  where COMP24FL="N";
  table DCREASCD* TRT01PN/ chisq fisher exact;
run;

/*STEP 4 Create the pivot for COMP24FL DCREASCD*/
DATA REPORT_2_EARLY;
	SET ADSL_REPORT_1;
	WHERE ITTFL = 'Y' AND COMP24FL ^= 'Y';
	KEEP COMP24FL DCREASCD TRT01PN;
RUN;

PROC FREQ DATA = REPORT_2_EARLY noprint;
	TABLES DCREASCD*TRT01PN/LIST MISSING SPARSE
	OUT = COMPFL_WHY_TABLE(KEEP = DCREASCD TRT01PN COUNT);
RUN;


/*STEP 5 TRANSPOSE*/

PROC TRANSPOSE DATA = COMPFL_WHY_TABLE OUT = COMPFL_WHY_TRANS(DROP = _NAME_ _LABEL_);
	ID TRT01PN;
	BY DCREASCD;
	VAR COUNT;
RUN;


/*STEP 6 Caculate Percent*/

DATA COMP_REASON;
	LENGTH Reason $40;
	SET COMPFL_WHY_TRANS END = LAST;
	
	IF DCREASCD = 'Adverse Event' THEN DO;
		ORD = 1;
		Reason = 'Adverse event';
	END;
	ELSE IF DCREASCD = 'Death' THEN DO;
		ORD = 2;
		Reason = 'Death';
	END;
	ELSE IF DCREASCD = 'Lack of Efficacy' THEN DO;
		ORD = 3;
		Reason = 'Lack of efficacy [2]';
	END;
	ELSE IF DCREASCD = 'Lost to Follow-up' THEN DO;
		ORD = 4;
		Reason = 'Lost to follow-up';
	END;
	ELSE IF DCREASCD = 'Withdrew Consent' THEN DO;
		ORD = 5;
		Reason = 'Subject decided to withdraw';
	END;
	ELSE IF DCREASCD = 'Physician Decision' THEN DO;
		ORD = 6;
		Reason = 'Physician decided to withdraw subject';
	END;
	ELSE IF DCREASCD = 'I/E Not Met' THEN DO;
		ORD = 7;
		Reason = 'Protocol criteria not met';
	END;
	ELSE IF DCREASCD = 'Protocol Violation' THEN DO;
		ORD = 8;
		Reason = 'Protocol violation';
	END;
	ELSE IF DCREASCD = 'Sponsor Decision' THEN DO;
		ORD = 9;
		Reason = 'Sponsor decision';
	END;
	OUTPUT; 
	
	IF LAST THEN DO;
		ORD = 10;
		Reason = 'Missing';
		'0'N = 0;
		'54'N = 0;
		'81'N = 0;
		'99'N = 0;
		OUTPUT; 
	END;
	DROP DCREASCD; 
RUN;

PROC SORT DATA = COMP_REASON OUT = COMP_REASON_ORD;
	BY ORD;
RUN;

DATA COMP_WHY_PCT;
	SET COMP_REASON_ORD;
  	PCT_0 = 100*('0'N / &N0);
  	PCT_54 = 100*('54'N / &N54);
  	PCT_81 = 100*('81'N / &N81);
  	PCT_99 = 100*('99'N / &N99);
  	Placebo = '0'N||' ('||PUT(PCT_0,3.)||'%)';
	Low = '54'N||' ('||PUT(PCT_54,3.)||'%)';
	High = '81'N||' ('||PUT(PCT_81,3.)||'%)';
 	Total = '99'N||' ('||PUT(PCT_99,3.)||'%)';
 	BLK = 2;
 	KEEP Reason Placebo Low High Total BLK ORD;
RUN;

PROC PRINT DATA = COMP_WHY_PCT;
RUN;

PROC PRINT DATA = COMP_PCT;
RUN;

/*=================================================================================
					STACK two datasets and caculate P-value
=================================================================================*/

/*CHISQ FISHER Test for COMP STATUS*/
/*ODS TRACE ON;*/
ODS OUTPUT FishersExact = Fish_EXACT_COMP;
PROC FREQ DATA = ADAM.ADSL_V1;
	TABLES COMP24FL*TRT01P / CHISQ FISHER EXACT;	
	WHERE ITTFL = 'Y';
RUN;
/*ODS TRACE OFF;*/

PROC PRINT DATA = Fish_EXACT_COMP;
RUN;

DATA _NULL_;
	SET Fish_EXACT_COMP;
	WHERE Name1 = 'XP2_FISH';
	CALL SYMPUTX('P_COMP', PUT(nValue1, PVALUE6.4));
RUN;

%PUT &P_COMP;

/*CHISQ FISHER Test for COMP REASON*/

DATA TEST_FOR_AE;
	SET ADAM.ADSL_V1;
	WHERE ITTFL = 'Y';
	AEFL = IFC (COMP24FL = 'N' AND DCREASCD = 'Adverse Event' ,'Y', 'N');
	KEEP AEFL TRT01PN;
RUN;

PROC PRINT DATA = TEST_FOR_AE;
RUN;

/*ODS TRACE ON;*/
ODS OUTPUT FishersExact = Fisher_AE;
PROC FREQ DATA = TEST_FOR_AE;
	TABLES AEFL * TRT01PN / CHISQ FISHER EXACT;
RUN;
/*ODS TRACE OFF;*/

PROC PRINT DATA = Fisher_AE;
RUN;


/*CHISQ FISHER Test for COMP REASON*/
DATA TEST_FOR_EF;
	SET ADAM.ADSL_V1;
	WHERE ITTFL = 'Y';
	EFFL = IFC (COMP24FL = 'N' AND DCREASCD = 'Lack of Efficacy' ,'Y', 'N');
	KEEP EFFL TRT01PN;
RUN;

ODS OUTPUT FishersExact = Fisher_EF;
PROC FREQ DATA = TEST_FOR_EF;
	TABLES EFFL * TRT01PN/ CHISQ FISHER EXACT;
RUN;

DATA _NULL_;
	SET Fisher_AE Fisher_EF;
	WHERE Name1 = 'XP2_FISH';
	IF Table = 'Table AEFL * TRT01PN' THEN CALL SYMPUTX('P_AE', PUT(nValue1,PVALUE6.));
	IF Table = 'Table EFFL * TRT01PN' THEN CALL SYMPUTX('P_EF', PUT(nValue1,PVALUE6.));
RUN;

%PUT &P_COMP &P_AE &P_EF;

/*==================================================================================
						Combine the two datasets
==================================================================================*/

%PUT &P_COMP &P_AE &P_EF;

PROC PRINT DATA = COMP_WHY_PCT;
RUN;

PROC SORT DATA = COMP_PCT;
	BY ORD;
RUN;

PROC PRINT DATA = COMP_PCT;
RUN;

DATA COMP_FINAL;
	SET COMP_PCT(RENAME = (STATUS = Reason)) COMP_WHY_PCT;
	LENGTH PVAL $6;
	IF BLK = 1 AND ORD = 1 THEN PVAL = "&P_COMP";
	IF BLK = 2 AND ORD = 1 THEN PVAL = "&P_AE";
	IF BLK = 2 AND ORD = 3 THEN PVAL = "&P_EF";
	LABEL PVAL = 'p-value[1]';
RUN;

PROC PRINT DATA = COMP_FINAL;
RUN;


/*REPORT*/
PROC REPORT DATA = COMP_FINAL NOWINDOWS SPLIT = '|';
	COLUMNS BLK ORD Reason Placebo Low High Total PVAL;
	DEFINE BLK /ORDER NOPRINT;
	DEFINE ORD /ORDER NOPRINT;
	DEFINE Reason / DISPLAY ' ';
	DEFINE Placebo / DISPLAY "Placebo (N=&N0)"	CENTER;
	DEFINE Low / DISPLAY "Xanomeline Low Dose (N=&N54)" CENTER;
	DEFINE High / DISPLAY "Xanomeline High Dose (N=&N81)" CENTER;
	DEFINE Total / DISPLAY "Total (N=&N99)" CENTER;
	DEFINE PVAL / DISPLAY "p-value[1]" CENTER;
	
	COMPUTE BEFORE BLK / STYLE = [JUST = L];
		LENGTH HDR $60;
		IF BLK = 1 THEN HDR = 'Completion Status';
		ELSE IF BLK =2 THEN HDR = 'Reason for Early Termination (prior to Week 24)';
		LINE HDR $60.;
	ENDCOMP;
	
	COMPUTE AFTER BLK;
		LINE ' ';
	ENDCOMP;

RUN;

OPTIONS NODATE NONUMBER ORIENTATION = LANDSCAPE;
ODS ESCAPECHAR = '^';
ODS RTF FILE = "/home/u63793342/sasuser.v94/t14_1_02.rtf" STYLE = JOURNAL;

TITLE1 J=L 'CDISC SDTM/ADaM Pilot Project' J=R 'CDISCPILOT01';
TITLE2 J=L 'Protocol: CDISCPILOT01' J=R 'Page ^{thispage} of ^{lastpage}';
TITLE3 J=L 'Population: Intent-to-Treat';
TITLE4 BOLD 'Table 14-1.02';
TITLE5 'Summary of End of Study Data';

FOOTNOTE1 J=L "[1] Fisher's exact test.";
FOOTNOTE2 J=L '[2] Based on either patient/caregiver perception or physician perception.';

PROC REPORT DATA = COMP_FINAL NOWINDOWS SPLIT = '|';
	COLUMN BLK ORD Reason Placebo Low High Total PVAL;
	DEFINE BLK     / ORDER NOPRINT;
	DEFINE ORD     / ORDER NOPRINT;
	DEFINE Reason  / DISPLAY ' ' LEFT STYLE(COLUMN) = [LEFTMARGIN = 0.25in CELLWIDTH = 3.2in];
	DEFINE Placebo / DISPLAY "Placebo|(N=&N0)"               CENTER;
	DEFINE Low     / DISPLAY "Xanomeline|Low Dose|(N=&N54)"  CENTER;
	DEFINE High    / DISPLAY "Xanomeline|High Dose|(N=&N81)" CENTER;
	DEFINE Total   / DISPLAY "Total|(N=&N99)"                CENTER;
	DEFINE PVAL    / DISPLAY "p-value[1]"                    CENTER;

	/* 區塊標題列 */
	COMPUTE BEFORE BLK / STYLE = [JUST = L];
		LENGTH HDR $60;
		IF BLK = 1 THEN HDR = 'Completion Status';
		ELSE HDR = 'Reason for Early Termination (prior to Week 24)';
		LINE HDR $60.;
	ENDCOMP;

	/* 區塊之間空一行 */
	COMPUTE AFTER BLK;
		LINE ' ';
	ENDCOMP;
RUN;

ODS RTF CLOSE;
TITLE;
FOOTNOTE;

