/*==========================================================================
  Program   : t14_3_01.sas
  Study     : CDISCPILOT01
  Purpose   : Table 14-3.01 Primary Endpoint Analysis: ADAS Cog (11) -
              Change from Baseline to Week 24 - LOCF (Efficacy population)
              - Descriptive statistics for Baseline, Week 24 and change
              - Dose response: ANCOVA, dose as a continuous variable
              - Pairwise comparisons: ANCOVA, treatment as a class variable
  Input     : ADAM.ADQSADAS_V1
  Output    : PROC REPORT (RTF destination still to be added)
  Spec      : SAP 10.1.1 and Template 5; define.xml ARM Table_14-3.01
  Run after : setup.sas, adsl.sas, adqsadas.sas
  QC status : Dose-response p-value (0.245) and the Low vs Placebo row are
              verified against CSR Supporting Table 14-3.01; the other rows
              are still to be confirmed (see docs/qc_summary.md).
==========================================================================*/


/*=====================================================================================
					Table 14-3.01 Primary Endpoint Analysis: 
			ADAS-Cog - Summary at Week 24 - LOCF (Efficacy Population)
======================================================================================*/

/* Analysis subset: Efficacy population, window-selected (ANL01FL) Week 24 ACTOT
   records, LOCF records included. PARAMCD = 'ACTOT' (define ARM has 'ATOT'). */
DATA REPORT_ADAS_4;
	SET ADAM.ADQSADAS_V1;
	WHERE EFFFL='Y' and ANL01FL='Y' and AVISIT='Week 24' and PARAMCD="ACTOT";
	KEEP TRTPN AVAL BASE CHG SITEGR1;
RUN;
/*================== Treatment-group N for the column headers ====================*/
PROC FREQ DATA = REPORT_ADAS_4 NOPRINT;
	TABLES TRTPN /LIST SPARSE MISSING OUT = TRTPN_FREQ (KEEP = TRTPN COUNT);
RUN;

DATA _NULL_;
	SET TRTPN_FREQ;
	IF TRTPN = 0 THEN CALL SYMPUTX('N0', PUT(COUNT, 3.));
	ELSE IF TRTPN = 54 THEN CALL SYMPUTX('N54', PUT(COUNT, 3.));
	ELSE IF TRTPN = 81 THEN CALL SYMPUTX('N81', PUT(COUNT, 3.));
	ELSE IF TRTPN = 99 THEN CALL SYMPUTX('N99', PUT(COUNT, 3.));
RUN;

%PUT &N0 &N54 &N81;
/*================================================================================*/
/*============================================================================
		Descriptive statistics: Baseline (BASE), Week 24 (AVAL), Change (CHG)
==============================================================================*/

%MACRO REPORT_SUMMARY(VAR = );

DATA REPORT_&VAR;
	SET REPORT_ADAS_4;
	KEEP TRTPN &VAR;
RUN;

PROC MEANS DATA = REPORT_&VAR NWAY NOPRINT;
	CLASS TRTPN;
	VAR &VAR ;
	OUTPUT OUT = &VAR._FOR_TRANS  (DROP = _TYPE_ _FREQ_)
	N = N MEAN = Mean STD = SD MEDIAN = Median MAX = max MIN = min;
RUN;

PROC TRANSPOSE DATA = &VAR._FOR_TRANS OUT = &VAR._SUMM (DROP = _LABEL_);
	ID TRTPN;
RUN;

DATA _NULL_;
	SET &VAR._SUMM;
	IF _NAME_ = 'SD' THEN DO;
		CALL SYMPUTX('SD0',PUT('0'N, 5.2));
		CALL SYMPUTX('SD54',PUT('54'N, 5.2));
		CALL SYMPUTX('SD81',PUT('81'N, 5.2));
	END;
	ELSE IF _NAME_ = 'max' THEN DO;
		CALL SYMPUTX('max0',PUT('0'N, 3.));
		CALL SYMPUTX('max54',PUT('54'N, 3.));
		CALL SYMPUTX('max81',PUT('81'N, 3.));
	END;
	ELSE IF _NAME_ = 'min' THEN DO;
		CALL SYMPUTX('min0',PUT('0'N, 3.));
		CALL SYMPUTX('min54',PUT('54'N, 3.));
		CALL SYMPUTX('min81',PUT('81'N, 3.));
	END;
RUN;

DATA &VAR._SUMMARY;
	SET &VAR._SUMM;
	LENGTH _VAR $14 Placebo $40 High $40 Low $40;
	IF _NAME_ = 'N' THEN DO;
		_VAR = 'N';
		Placebo = PUT('0'N, 3.);
		Low = PUT('54'N, 3.);
		High = PUT('81'N, 3.);
	END;	
	ELSE IF _NAME_ = 'Mean' THEN DO;
		_VAR = 'Mean (SD)';
		Placebo = STRIP(PUT('0'N, 4.1))||' ('||"&SD0"||')';
		Low = STRIP(PUT('54'N, 4.1))||' ('||"&SD54"||')';
		High = STRIP(PUT('81'N, 4.1))||' ('||"&SD81"||')';
	END;
	ELSE IF _NAME_ = 'Median' THEN DO;
		_VAR = 'Median (Range)';
		Placebo = STRIP(PUT('0'N, 4.1))||' ('||"&min0; &max0"||')';
		Low = STRIP(PUT('54'N, 4.1))||' ('||"&min54; &max54"||')';
		High = STRIP(PUT('81'N, 4.1))||' ('||"&min81; &max81"||')';
	END;
	IF NOT MISSING(_VAR);
	KEEP _VAR Placebo Low High;
RUN;

%MEND REPORT_SUMMARY;

%REPORT_SUMMARY(VAR = BASE);
%REPORT_SUMMARY(VAR = AVAL);
%REPORT_SUMMARY(VAR = CHG);


/*============================================================================
	Dose response (define ARM R.1): TRTPN as a continuous variable.
	BASE added per SAP 10.1.1 and CSR footnote [1] (the define program omits it);
	verified against CSR Supporting Table 14-3.01: Type III p = 0.2447.
==============================================================================*/
ODS OUTPUT MODELANOVA = DR_ANOVA;
PROC GLM DATA = REPORT_ADAS_4;
    CLASS SITEGR1;
    MODEL CHG = TRTPN SITEGR1 BASE / SS3;
RUN;
QUIT;


/*============================================================================
	Pairwise comparisons (define ARM R.2): TRTPN as a class variable.
	ESTIMATE statements added because the table needs the SE of the LS-mean
	difference, which LSMEANS / PDIFF does not provide. Coefficients follow the
	class level order 0, 54, 81. Estimates, p-values and CIs equal LSMEANS PDIFF.
==============================================================================*/
ODS OUTPUT ESTIMATES = PW_EST;
PROC GLM DATA = REPORT_ADAS_4;
    CLASS TRTPN SITEGR1;
    MODEL CHG = TRTPN SITEGR1 BASE / CLPARM;
    ESTIMATE 'L VS P' TRTPN -1  1  0;
    ESTIMATE 'H VS P' TRTPN -1  0  1;
    ESTIMATE 'H VS L' TRTPN  0 -1  1;
    LSMEANS TRTPN / OM STDERR PDIFF CL;
RUN;
QUIT;

DATA _NULL_;
    SET DR_ANOVA;
    WHERE SOURCE = 'TRTPN';
    CALL SYMPUTX('P_DR', PUT(PROBF, PVALUE6.3));
RUN;

DATA _NULL_;
    SET PW_EST;
    LENGTH P_C $6 D_C CI_C $20;
    P_C  = PUT(PROBT, PVALUE6.3);
    D_C  = STRIP(PUT(ESTIMATE, 5.1)) || ' (' || STRIP(PUT(STDERR, 5.2)) || ')';
    CI_C = '(' || STRIP(PUT(LOWERCL, 6.2)) || ';' || STRIP(PUT(UPPERCL, 6.2)) || ')';

    IF PARAMETER = 'L VS P' THEN DO;
        CALL SYMPUTX('P_LP', P_C);  CALL SYMPUTX('D_LP', D_C);  CALL SYMPUTX('CI_LP', CI_C);
    END;
    ELSE IF PARAMETER = 'H VS P' THEN DO;
        CALL SYMPUTX('P_HP', P_C);  CALL SYMPUTX('D_HP', D_C);  CALL SYMPUTX('CI_HP', CI_C);
    END;
    ELSE IF PARAMETER = 'H VS L' THEN DO;
        CALL SYMPUTX('P_HL', P_C);  CALL SYMPUTX('D_HL', D_C);  CALL SYMPUTX('CI_HL', CI_C);
    END;
RUN;

DATA STAT_SUMMARY;
    LENGTH _VAR $40 Placebo Low High $40;

    CALL MISSING(_VAR, Placebo, Low, High);      OUTPUT;   /* blank row */
    _VAR = 'P-value(Dose Response) [1][2]';      High = "&P_DR";                    OUTPUT;

    CALL MISSING(_VAR, Placebo, Low, High);      OUTPUT;   /* blank row */
    _VAR = 'P-value(Xan - Placebo) [1][3]';      Low = "&P_LP";  High = "&P_HP";    OUTPUT;
    _VAR = 'Diff. of LS Means (SE)';             Low = "&D_LP";  High = "&D_HP";    OUTPUT;
    _VAR = '95% CI';                             Low = "&CI_LP"; High = "&CI_HP";   OUTPUT;

    CALL MISSING(_VAR, Placebo, Low, High);      OUTPUT;   /* blank row */
    _VAR = 'P-value(Xan High - Xan Low) [1][3]'; High = "&P_HL";                    OUTPUT;
    _VAR = 'Diff. of LS Means (SE)';             High = "&D_HL";                    OUTPUT;
    _VAR = '95% CI';                             High = "&CI_HL";                   OUTPUT;
RUN;


DATA BODY;
    LENGTH _VAR $40 Placebo Low High $40;      /* must precede SET: _VAR is $14 in the *_SUMMARY datasets */
    SET BASE_SUMMARY (IN = A)
        AVAL_SUMMARY (IN = B)
        CHG_SUMMARY
        STAT_SUMMARY;

    IF A THEN BLK = 1;
    ELSE IF B THEN BLK = 2;
    ELSE BLK = 3;

    ORD   = _N_;     /* row sequence in stacking order */
    HDRFL = 0;

    /* indentation: 4 spaces for statistic rows, 5 for Diff and CI rows */
    IF _VAR IN ('Diff. of LS Means (SE)', '95% CI') THEN _VAR = '     ' || _VAR;
    ELSE IF NOT MISSING(_VAR) THEN _VAR = '    ' || _VAR;
RUN;


DATA HEADER;
    LENGTH _VAR $40 Placebo Low High $40;
    CALL MISSING(Placebo, Low, High);

    HDRFL = 1;  ORD = 0;
    BLK = 1;  _VAR = 'Baseline';              OUTPUT;
    BLK = 2;  _VAR = 'Week 24';               OUTPUT;
    BLK = 3;  _VAR = 'Change from Baseline';  OUTPUT;

    HDRFL = 0;  ORD = 999;  _VAR = '';
    BLK = 1;  OUTPUT;
    BLK = 2;  OUTPUT;
RUN;

DATA FINAL_ADAS;
    SET HEADER BODY;
RUN;

PROC SORT DATA = FINAL_ADAS;
    BY BLK ORD;
RUN;

/*============================================================================
		Display. TODO: ODS RTF destination and TITLE1-2 (protocol, page x of y)
		as in t14_2_01.sas - see docs/review_notes.md
==============================================================================*/
TITLE3 'Table 14-3.01';
TITLE4 'Primary Endpoint Analysis: ADAS Cog (11) - Change from Baseline to Week 24 - LOCF';

FOOTNOTE1 J=L '[1] Based on Analysis of covariance (ANCOVA) model with treatment and site as factors, and baseline ADAS Cog (11) value as a covariate.';
FOOTNOTE2 J=L '[2] Test for a non-zero coefficient for treatment (dose) as a continuous variable.';
FOOTNOTE3 J=L '[3] Pairwise comparison with treatment as a categorical variable: p-values without adjustment for multiple comparisons.';

PROC REPORT DATA = FINAL_ADAS NOWD SPLIT = '|' STYLE(REPORT) = [OUTPUTWIDTH = 100%];
    COLUMN BLK ORD HDRFL _VAR Placebo Low High;

    DEFINE BLK     / ORDER NOPRINT;
    DEFINE ORD     / ORDER NOPRINT;
    DEFINE HDRFL   / DISPLAY NOPRINT;
    DEFINE _VAR    / DISPLAY ' '                            STYLE(COLUMN) = [ASIS = ON CELLWIDTH = 34%];
    DEFINE Placebo / DISPLAY "Placebo|(N=&N0)"              CENTER STYLE(COLUMN) = [CELLWIDTH = 22%];
    DEFINE Low     / DISPLAY "Xanomeline|Low Dose|(N=&N54)"  CENTER STYLE(COLUMN) = [CELLWIDTH = 22%];
    DEFINE High    / DISPLAY "Xanomeline|High Dose|(N=&N81)" CENTER STYLE(COLUMN) = [CELLWIDTH = 22%];

    COMPUTE _VAR;
        IF HDRFL = 1 THEN CALL DEFINE(_ROW_, 'STYLE', 'STYLE=[FONT_WEIGHT=BOLD]');
    ENDCOMP;
RUN;
