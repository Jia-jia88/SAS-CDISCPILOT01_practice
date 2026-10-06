/*==========================================================================
  Program   : t14_2_01.sas
  Study     : CDISCPILOT01
  Purpose   : Table 14-2.01 Summary of Demographic and Baseline
              Characteristics (ITT population)
              Continuous variables: n, mean, SD, median, min, max and
              one-way ANOVA p-value; categorical variables: n (%) and
              Pearson chi-square p-value.
  Input     : ADAM.ADSL_V1
  Output    : &OUTPATH/t14_2_01.rtf
  Spec      : SAP Template 3; define.xml analysis results metadata
  Run after : setup.sas, adsl.sas
  Macros    : CREATE_CON_FREQ, CREATE_CAT_FREQ  - summary statistics
              PEARSON_TEST, ANOVA_TEST          - p-values (global macro vars)
              IMPUT_PVAL_CON, IMPUT_PVAL_CAT    - place p-values on the table
  Notes     : Numeric display formats are an open item - see
              docs/review_notes.md.
==========================================================================*/


/*=================================================================================================
		Table 14-2.01 Summary of Demographic and Baseline Characteristics (ITT population)
===================================================================================================*/
DATA REPORT_3;
	SET ADAM.ADSL_V1;
	OUTPUT;
	TRT01PN = 99;
	OUTPUT;
RUN;

PROC FREQ DATA = REPORT_3 NOPRINT;
	TABLES TRT01PN /MISSING LIST OUT = FOR_ITTFL_N (KEEP = TRT01PN COUNT);
RUN;

DATA _NULL_;
	SET FOR_ITTFL_N;
	IF TRT01PN = 0 THEN CALL SYMPUTX('N0', PUT(COUNT, 3.));
	ELSE IF TRT01PN = 54 THEN CALL SYMPUTX('N54', PUT(COUNT, 3.));
	ELSE IF TRT01PN = 81 THEN CALL SYMPUTX('N81', PUT(COUNT, 3.));
	ELSE IF TRT01PN = 99 THEN CALL SYMPUTX('N99', PUT(COUNT, 3.)); 
RUN;

/*================================= Basic Check =======================================*/
PROC FREQ DATA = REPORT_3;
	TABLES (AGEGR1 SEX RACE DURDSGR1 BMIBLGR1)*TRT01PN /MISSING LIST;
	WHERE ITTFL = 'Y';
RUN;

DATA REPORT_CAT_3;
	SET REPORT_3;
	WHERE ITTFL = 'Y';
	KEEP AGEGR1 SEX RACE DURDSGR1 BMIBLGR1 TRT01PN;
RUN;

DATA REPORT_CON_3;
	SET REPORT_3;
	WHERE ITTFL = 'Y';
	KEEP AGE MMSETOT DURDIS EDUCLVL WEIGHTBL HEIGHTBL BMIBL TRT01PN;
RUN;
/*============================================================================================						
								MACRO FOR TABLE
=============================================================================================*/

/*=================================================================================*/
/*MACRO for Continuous variables*/
%MACRO CREATE_CON_FREQ (DATA=, VAR=, BLK=);

DATA _&VAR;
	SET &DATA;
	KEEP TRT01PN &VAR;
RUN;


PROC MEANS DATA = _&VAR NWAY NOPRINT;
	CLASS TRT01PN;
	VAR &VAR;
	OUTPUT OUT = _&VAR._FOR_TRANS (DROP = _TYPE_ _FREQ_)
	N = n  MEAN = Mean  STD = SD  MEDIAN = Median  MIN = Min  MAX = Max;
RUN;

PROC TRANSPOSE DATA =_&VAR._FOR_TRANS OUT = _&VAR._SUMM(DROP = _LABEL_);
	ID TRT01PN;
RUN;

DATA _&VAR._SUMMARY;
	SET _&VAR._SUMM (RENAME = (_NAME_ = &VAR));
	
	Placebo = PUT('0'N,3.);
	Low = PUT('54'N,3. ) ;
	High = PUT('81'N,3.);
	Total = PUT('99'N,3.);
	
	IF &VAR = 'n' THEN ORD = 1;
	ELSE IF &VAR = 'Mean' THEN ORD = 2;
	ELSE IF &VAR = 'SD' THEN ORD = 3;
	ELSE IF &VAR = 'Median' THEN ORD = 4;
	ELSE IF &VAR = 'Min' THEN ORD = 5;
	ELSE IF &VAR = 'Max' THEN ORD = 6;
	BLK = &BLK;
	
	KEEP &VAR Placebo Low High Total ORD BLK;
RUN;


%MEND CREATE_CON_FREQ;
/*=================================================================================*/
/*MACRO for Category variables*/
/*=================================================================================*/
%MACRO CREATE_CAT_FREQ(DATA=, VAR=, BLK=);

DATA _&VAR;
	SET &DATA;
	KEEP &VAR TRT01PN;
RUN;

PROC FREQ DATA = _&VAR NOPRINT;
	TABLES &VAR * TRT01PN/LIST SPARSE OUT = _&VAR._FOR_TRANS (KEEP = &VAR TRT01PN COUNT);
RUN;

PROC TRANSPOSE DATA = _&VAR._FOR_TRANS OUT = _&VAR._CON (DROP = _NAME_ _LABEL_);
	BY &VAR;
	ID TRT01PN;
	VAR COUNT;
RUN;

PROC MEANS DATA = _&VAR._FOR_TRANS NWAY NOPRINT;
	CLASS TRT01PN;
	VAR COUNT;
	OUTPUT OUT = _&VAR._SUM (DROP = _TYPE_ _FREQ_) SUM =;
RUN;


DATA _NULL_;
	SET _&VAR._SUM;
	IF TRT01PN = 0 THEN CALL SYMPUTX('N0', PUT(COUNT,3.));
	ELSE IF TRT01PN = 54 THEN CALL SYMPUTX('N54', PUT(COUNT, 3.));
	ELSE IF TRT01PN = 81 THEN CALL SYMPUTX('N81', PUT(COUNT, 3.));
	ELSE IF TRT01PN = 99 THEN CALL SYMPUTX('N99', PUT(COUNT, 3.));
RUN;

PROC TRANSPOSE DATA = _&VAR._SUM OUT = _&VAR._SUM_STACK (DROP = _LABEL_);
	ID TRT01PN;
	VAR COUNT;
RUN;

DATA _&VAR.SUMM;
	SET _&VAR._CON;
    
    PCT_0 = '0'N / &N0 * 100;
	PCT_54 = '54'N / &N54 * 100;
	PCT_81 = '81'N / &N81 * 100;
	PCT_99 = '99'N/ &N99 *100;
	
	Placebo = STRIP(PUT('0'N, 3.))||' ('||STRIP(PUT(PCT_0, 3.))||'%)';
	Low = STRIP(PUT('54'N, 3.))||' ('||STRIP(PUT(PCT_54, 3.))||'%)';
	High = STRIP(PUT('81'N, 3.))||' ('||STRIP(PUT(PCT_81, 3.))||'%)';
	Total = STRIP(PUT('99'N, 3.))||' ('||STRIP(PUT(PCT_99, 3.))||'%)';
    KEEP &VAR Placebo Low High Total;
RUN;

DATA _&VAR._N;
  SET _&VAR._SUM_STACK (RENAME = (_NAME_= &VAR));
  &VAR = 'n';
  Placebo = STRIP(PUT('0'N,  3.));
  Low     = STRIP(PUT('54'N, 3.));
  High    = STRIP(PUT('81'N, 3.));
  Total   = STRIP(PUT('99'N, 3.));
  KEEP &VAR Placebo Low High Total;
RUN;

DATA _&VAR._SUMMARY;
	LENGTH &VAR $40 Placebo Low High Total $40;
	SET _&VAR._N _&VAR.SUMM;
	BLK = &BLK;
	KEEP &VAR Placebo Low High Total BLK;
RUN;


%MEND CREATE_CAT_FREQ;
/*=================================================================================*/


/*==========================================================================================
                    Pearson Chi-square Test For Discrete Variables
============================================================================================*/
/*=================================================================================*/
%MACRO PEARSON_TEST(DATA = , VAR = );

ODS OUTPUT ChiSq = _&VAR._chisq;
PROC FREQ DATA = &DATA;
    WHERE TRT01PN IN (0, 54, 81);
    TABLES &VAR * TRT01PN/CHISQ;
RUN;

DATA _NULL_;
    SET _&VAR._chisq;
    WHERE Statistic = 'Chi-Square';
    CALL SYMPUTX("_&VAR._PVALUE",PUT(Prob, PVALUE5.3), 'G');
RUN;

%PUT &&_&VAR._PVALUE;

%MEND PEARSON_TEST;
/*=================================================================================*/

/*=======================================================================================
                        ANOVA Test For Continuous Variables
=========================================================================================*/
/*=================================================================================*/
%MACRO ANOVA_TEST(DATA= ,VAR= );
ODS OUTPUT OverallANOVA = _&VAR._ANOVA;
PROC GLM DATA = &DATA;
    WHERE TRT01PN IN (0, 54, 81);
    CLASS TRT01PN;
    MODEL &VAR = TRT01PN;
RUN;
QUIT;

DATA _NULL_;
    SET _&VAR._ANOVA;
    WHERE Source = 'Model';
    CALL SYMPUTX("_&VAR._PVALUE", PUT(ProbF, PVALUE5.3), 'G');
RUN;

%PUT &&_&VAR._PVALUE;
%MEND ANOVA_TEST;
/*=================================================================================*/
/*===================================================================================
                       Populate pvalue in Data
====================================================================================*/
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= AGE, BLK = 1);
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= MMSETOT, BLK = 5);
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= DURDIS, BLK = 6);
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= EDUCLVL, BLK = 8);
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= WEIGHTBL, BLK = 9);
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= HEIGHTBL, BLK = 10);
%CREATE_CON_FREQ(DATA=REPORT_CON_3, VAR= BMIBL, BLK = 11);

%CREATE_CAT_FREQ(DATA = REPORT_CAT_3, VAR = AGEGR1, BLK = 2);
%CREATE_CAT_FREQ(DATA = REPORT_CAT_3, VAR = SEX, BLK = 3);
%CREATE_CAT_FREQ(DATA = REPORT_CAT_3, VAR = RACE, BLK = 4);
%CREATE_CAT_FREQ(DATA = REPORT_CAT_3, VAR = DURDSGR1, BLK = 7);
%CREATE_CAT_FREQ(DATA = REPORT_CAT_3, VAR = BMIBLGR1, BLK = 12);

/* Category order and display labels (run after the CREATE_CAT_FREQ calls,
   which create the _<VAR>_SUMMARY datasets used here) */
DATA _AGEGR1_SUMMARY_REVISE;
	SET _AGEGR1_SUMMARY;
	IF AGEGR1 NOT IN ('n');
	
	IF AGEGR1 = '<65' THEN ORD = 1;
	ELSE IF AGEGR1 = '65-80' THEN ORD = 2;
	ELSE IF AGEGR1 = '>80' THEN ORD = 3;
RUN;

DATA _SEX_SUMMARY_REVISE;
	SET _SEX_SUMMARY;
	IF SEX = 'n' THEN ORD = 1;
	ELSE IF SEX = 'F' THEN ORD = 2;
	ELSE IF SEX = 'M' THEN ORD = 3;
RUN;

DATA _RACE_SUMMARY_REVISE;
	SET _RACE_SUMMARY;
	IF RACE = 'n' THEN ORD = 1;
	ELSE IF RACE = 'BLACK OR AFRICAN AMERICAN' THEN DO;
		ORD = 2;
		RACE = 'Black';
	END;
	ELSE IF RACE = 'WHITE' THEN DO;
		ORD = 3;
		RACE = 'White';
	END;
	ELSE IF RACE = 'AMERICAN INDIAN OR ALASKA NATIVE' THEN DO;
		ORD = 4;
		RACE = 'American Indian or Alaska Native';
	END;
RUN;

DATA _DURDSGR1_SUMMARY_REVISE;
	SET _DURDSGR1_SUMMARY;
	IF DURDSGR1 NOT IN ('n');

	IF DURDSGR1 = '<12' THEN ORD = 1;
	ELSE IF DURDSGR1 = '>=12' THEN ORD = 2;
RUN;

DATA _BMIBLGR1_SUMMARY_REVISE;
	SET _BMIBLGR1_SUMMARY;
	IF BMIBLGR1 NOT IN ('n');
	
	IF BMIBLGR1 = '<25' THEN ORD = 1;
	ELSE IF BMIBLGR1 = '25-<30' THEN ORD = 2;
	ELSE IF BMIBLGR1 = '>=30' THEN ORD = 3;
RUN;

%PEARSON_TEST(DATA = REPORT_CAT_3, VAR= AGEGR1);
%PEARSON_TEST(DATA = REPORT_CAT_3, VAR= SEX);
%PEARSON_TEST(DATA = REPORT_CAT_3, VAR= RACE);
%PEARSON_TEST(DATA = REPORT_CAT_3, VAR= DURDSGR1);
%PEARSON_TEST(DATA = REPORT_CAT_3, VAR= BMIBLGR1);

%ANOVA_TEST(DATA = REPORT_CON_3, VAR = AGE);
%ANOVA_TEST(DATA = REPORT_CON_3, VAR = MMSETOT);
%ANOVA_TEST(DATA = REPORT_CON_3, VAR = DURDIS);
%ANOVA_TEST(DATA = REPORT_CON_3, VAR = EDUCLVL);
%ANOVA_TEST(DATA = REPORT_CON_3, VAR = HEIGHTBL);
%ANOVA_TEST(DATA = REPORT_CON_3, VAR = WEIGHTBL);
%ANOVA_TEST(DATA = REPORT_CON_3, VAR = BMIBL);


%PUT &=_AGE_PVALUE &=_AGEGR1_PVALUE &=_SEX_PVALUE &=_RACE_PVALUE &=_DURDSGR1_PVALUE &=_BMIBLGR1_PVALUE;
%PUT &=_MMSETOT_PVALUE &=_DURDIS_PVALUE &=_EDUCLVL_PVALUE &=_HEIGHTBL_PVALUE &=_WEIGHTBL_PVALUE &=_BMIBL_PVALUE;


/*=================================================================================*/
%MACRO IMPUT_PVAL_CON(VAR=);
DATA &VAR._SUMMARY_FINAL;
	SET _&VAR._SUMMARY;
	IF ORD = 2 THEN PVALUE = &&_&VAR._PVALUE;
RUN;
%MEND IMPUT_PVAL_CON;
/*=================================================================================*/

/*=================================================================================*/
%MACRO IMPUT_PVAL_CAT(VAR=);
DATA &VAR._SUMMARY_FINAL;
	SET _&VAR._SUMMARY_REVISE;
	IF ORD = 1  THEN PVALUE = &&_&VAR._PVALUE;
RUN;
%MEND IMPUT_PVAL_CAT;
/*=================================================================================*/
%IMPUT_PVAL_CON(VAR= AGE);
%IMPUT_PVAL_CON(VAR= MMSETOT);
%IMPUT_PVAL_CON(VAR= DURDIS);
%IMPUT_PVAL_CON(VAR= EDUCLVL);
%IMPUT_PVAL_CON(VAR= WEIGHTBL);
%IMPUT_PVAL_CON(VAR= HEIGHTBL);
%IMPUT_PVAL_CON(VAR= BMIBL);
%IMPUT_PVAL_CAT(VAR= AGEGR1);
%IMPUT_PVAL_CAT(VAR= SEX);
%IMPUT_PVAL_CAT(VAR= RACE);
%IMPUT_PVAL_CAT(VAR= DURDSGR1);
%IMPUT_PVAL_CAT(VAR= BMIBLGR1);


/*==================================================================================
							STACK ALL DATA
====================================================================================*/

DATA DEMO_BASE_TABLE;
	LENGTH _VAR $200 Placebo Low High Total $50;
	SET AGE_SUMMARY_FINAL(RENAME=(AGE = _VAR))
	 AGEGR1_SUMMARY_FINAL(RENAME=(AGEGR1 = _VAR))
	 MMSETOT_SUMMARY_FINAL(RENAME=(MMSETOT = _VAR))
	 DURDIS_SUMMARY_FINAL(RENAME=(DURDIS = _VAR))
	 EDUCLVL_SUMMARY_FINAL(RENAME=(EDUCLVL = _VAR))
	 WEIGHTBL_SUMMARY_FINAL(RENAME=(WEIGHTBL = _VAR))
	 HEIGHTBL_SUMMARY_FINAL(RENAME=(HEIGHTBL = _VAR))
	 BMIBL_SUMMARY_FINAL(RENAME=(BMIBL = _VAR))
	 SEX_SUMMARY_FINAL(RENAME=(SEX = _VAR))
	 RACE_SUMMARY_FINAL(RENAME=(RACE = _VAR))
	 DURDSGR1_SUMMARY_FINAL(RENAME=(DURDSGR1 = _VAR))
	 BMIBLGR1_SUMMARY_FINAL(RENAME=(BMIBLGR1 = _VAR));
RUN;

PROC SORT DATA = DEMO_BASE_TABLE OUT = DEMO_BASE_FINAL;
	BY BLK ORD;
RUN;

DATA DEMO_REPORT;
LENGTH PARAM $40;
SET DEMO_BASE_FINAL;
IF BLK IN (1, 2)        THEN DO; PARAMN = 1; PARAM = 'Age (y)';              END;
ELSE IF BLK = 3         THEN DO; PARAMN = 2; PARAM = 'Sex';                  END;
ELSE IF BLK = 4         THEN DO; PARAMN = 3; PARAM = 'Origin';               END;
ELSE IF BLK = 5         THEN DO; PARAMN = 4; PARAM = 'MMSE';                 END;
ELSE IF BLK IN (6, 7)   THEN DO; PARAMN = 5; PARAM = 'Duration of disease';  END;
ELSE IF BLK = 8         THEN DO; PARAMN = 6; PARAM = 'Years of education';   END;
ELSE IF BLK = 9         THEN DO; PARAMN = 7; PARAM = 'Baseline weight (kg)'; END;
ELSE IF BLK = 10        THEN DO; PARAMN = 8; PARAM = 'Baseline height (cm)'; END;
ELSE IF BLK IN (11, 12) THEN DO; PARAMN = 9; PARAM = 'Baseline BMI (kg/m2)'; END;

RUN;



/*==================================================================================
						Output Table 14-2.01 to RTF
====================================================================================*/
ODS ESCAPECHAR = '^';
OPTIONS NODATE NONUMBER ORIENTATION = LANDSCAPE MISSING = ' ';
ODS RTF FILE = "&OUTPATH/t14_2_01.rtf" STYLE = JOURNAL;

TITLE1 J=L "CDISC SDTM/ADaM Pilot Project" J=R "CDISCPILOT01";
TITLE2 J=L "Protocol: CDISCPILOT01" J=R "Page ^{thispage} of ^{lastpage}";
TITLE3 J=L "Population: Intent-to-Treat";
TITLE4 J=C "Table 14-2.01";
TITLE5 J=C "Summary of Demographic and Baseline Characteristics";

FOOTNOTE1 J=L "[1] P-values are results of ANOVA treatment group comparisons for continuous variables and Pearson's chi-square test for categorical variables.";
FOOTNOTE2 J=L "NOTE: Duration of disease is computed as months between date of enrollment and date of onset of the first definite symptoms of Alzheimer's disease.";

PROC REPORT DATA = DEMO_REPORT NOWINDOWS SPLIT = '|';
    COLUMNS PARAMN PARAM BLK ORD _VAR Placebo Low High Total PVALUE;
    DEFINE PARAMN  / ORDER NOPRINT;
    DEFINE PARAM   / ORDER ' ' LEFT;
    DEFINE BLK     / ORDER NOPRINT;
    DEFINE ORD     / ORDER NOPRINT;
    DEFINE _VAR    / DISPLAY ' ' LEFT;
    DEFINE Placebo / DISPLAY "Placebo|(N=&N0)" CENTER;
    DEFINE Low     / DISPLAY "Xanomeline|Low Dose|(N=&N54)" CENTER;
    DEFINE High    / DISPLAY "Xanomeline|High Dose|(N=&N81)" CENTER;
    DEFINE Total   / DISPLAY "Total|(N=&N99)" CENTER;
    DEFINE PVALUE  / DISPLAY "p-value [1]" FORMAT=PVALUE5.3 CENTER;

    COMPUTE AFTER BLK;
        LINE ' ';
    ENDCOMP;
RUN;


ODS RTF CLOSE;
TITLE; FOOTNOTE;
