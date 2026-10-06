LIBNAME ADAM "/home/u63793342/sasuser.v94";

/*=====================================================================================
					Table 14-3.01 Primary Endpoint Analysis: 
			ADAS-Cog - Summary at Week 24 - LOCF (Efficacy Population)
======================================================================================*/

/*==============================Basic Check==========================*/

proc glm data = ADAM.ADQSADAS_V1;
  where EFFFL='Y' and ANL01FL='Y' and AVISIT='Week 24' and PARAMCD="ACTOT";
  class sitegr1;
  model CHG = trtpn sitegr1;
run;
	
proc glm data = ADAM.ADQSADAS_V1;
  where EFFFL='Y' and ANL01FL='Y' and AVISIT='Week 24' and PARAMCD="ACTOT";
  class trtpn sitegr1;
  model CHG = trtpn sitegr1 base;
  means trtpn;
  lsmeans trtpn / OM STDERR PDIFF CL;
run;
/*================================================================*/
DATA REPORT_ADAS_4;
	SET ADAM.ADQSADAS_V1;
	WHERE EFFFL='Y' and ANL01FL='Y' and AVISIT='Week 24' and PARAMCD="ACTOT";
	KEEP TRTPN AVAL BASE CHG SITEGR1;
RUN;
/*=================================== FOR TOTAL MACRO ===========================*/
PROC FREQ DATA = REPORT_ADAS_4 NOPRINT;
	TABLES TRTPN /LIST SPARSE MISSING OUT = TRTPN_FREQ (KEEP = TRTPN COUNT);
RUN;

PROC PRINT DATA = TRTPN_FREQ;
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
							Block about Baseline
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

PROC PRINT DATA = &VAR._SUMMARY;
RUN;

%MEND REPORT_SUMMARY;

%REPORT_SUMMARY(VAR = BASE);
%REPORT_SUMMARY(VAR = AVAL);
%REPORT_SUMMARY(VAR = CHG);


ODS OUTPUT MODELANOVA = DR_ANOVA;
PROC GLM DATA = REPORT_ADAS_4;
    CLASS SITEGR1;
    MODEL CHG = TRTPN SITEGR1 BASE / SS3;
RUN;
QUIT;

PROC PRINT DATA = DR_ANOVA;   /* 先確認欄位名稱 */
RUN;


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

PROC PRINT DATA = PW_EST;
RUN;

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

    CALL MISSING(Placebo, Low, High);
    _VAR = 'P-value(Dose Response) [1][2]';      High = "&P_DR";                    OUTPUT;

    CALL MISSING(Placebo, Low, High);
    _VAR = 'P-value(Xan - Placebo) [1][3]';      Low = "&P_LP";  High = "&P_HP";    OUTPUT;
    _VAR = 'Diff. of LS Means (SE)';             Low = "&D_LP";  High = "&D_HP";    OUTPUT;
    _VAR = '95% CI';                             Low = "&CI_LP"; High = "&CI_HP";   OUTPUT;

    CALL MISSING(Placebo, Low, High);
    _VAR = 'P-value(Xan High - Xan Low) [1][3]'; High = "&P_HL";                    OUTPUT;
    _VAR = 'Diff. of LS Means (SE)';             High = "&D_HL";                    OUTPUT;
    _VAR = '95% CI';                             High = "&CI_HL";                   OUTPUT;
RUN;


DATA STAT_SUMMARY;
    LENGTH _VAR $40 Placebo Low High $40;

    CALL MISSING(_VAR, Placebo, Low, High);      OUTPUT;   /* 空白列 */
    _VAR = 'P-value(Dose Response) [1][2]';      High = "&P_DR";                    OUTPUT;

    CALL MISSING(_VAR, Placebo, Low, High);      OUTPUT;   /* 空白列 */
    _VAR = 'P-value(Xan - Placebo) [1][3]';      Low = "&P_LP";  High = "&P_HP";    OUTPUT;
    _VAR = 'Diff. of LS Means (SE)';             Low = "&D_LP";  High = "&D_HP";    OUTPUT;
    _VAR = '95% CI';                             Low = "&CI_LP"; High = "&CI_HP";   OUTPUT;

    CALL MISSING(_VAR, Placebo, Low, High);      OUTPUT;   /* 空白列 */
    _VAR = 'P-value(Xan High - Xan Low) [1][3]'; High = "&P_HL";                    OUTPUT;
    _VAR = 'Diff. of LS Means (SE)';             High = "&D_HL";                    OUTPUT;
    _VAR = '95% CI';                             High = "&CI_HL";                   OUTPUT;
RUN;


DATA BODY;
    LENGTH _VAR $40 Placebo Low High $40;      /* 必須在 SET 之前，_VAR 原本只有 $14 */
    SET BASE_SUMMARY (IN = A)
        AVAL_SUMMARY (IN = B)
        CHG_SUMMARY
        STAT_SUMMARY;

    IF A THEN BLK = 1;
    ELSE IF B THEN BLK = 2;
    ELSE BLK = 3;

    ORD   = _N_;     /* 依疊入的順序編號，排序時保持原順序 */
    HDRFL = 0;

    /* 縮排：一般列 4 格，Diff 和 CI 列 5 格 */
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

PROC PRINT DATA = FINAL_ADAS;
RUN;

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


/*=====================================================================================
					Table 14-3.02 Primary Endpoint Analysis: 
				CIBIC+ - Summary at Week 24 - LOCF (Efficacy Population)
======================================================================================*/

/*==============================Basic Check==============================*/

proc glm data = ADAM.ADQSCIBC_V1;
  where EFFFL='Y' and ANL01FL='Y' and AVISIT='Week 24' and PARAMCD="CIBICVAL";
  class sitegr1;
  model AVAL = trtpn sitegr1;
run;





