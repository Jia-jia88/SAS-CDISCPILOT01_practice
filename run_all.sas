/*==========================================================================
  Program   : run_all.sas
  Purpose   : Re-run the whole CDISCPILOT01 pipeline in dependency order
              in a fresh SAS session: ADSL -> other ADaM -> TFL.
  Usage     : 1. Edit REPO below to the folder where this repository lives.
              2. Edit ROOT in setup.sas to the folder that holds the .xpt files.
              3. Submit this file and review the LOG for ERROR / WARNING.
  Notes     : WORK is cleared between programs so that no program can
              silently depend on a dataset left behind by another one.
==========================================================================*/

%LET REPO = /home/<your-user-id>/cdiscpilot01-sas-portfolio;

%INCLUDE "&REPO/setup.sas";

%MACRO CLEAN_WORK;
    PROC DATASETS LIBRARY = WORK KILL NOLIST;
    QUIT;
%MEND CLEAN_WORK;

%MACRO RUN_PGM(PGM);
    %PUT NOTE: ===== Running &PGM =====;
    %INCLUDE "&REPO/programs/&PGM..sas";
    %CLEAN_WORK;
%MEND RUN_PGM;

/*--- ADaM (order follows the dependency chain) ---*/
%RUN_PGM(adam/adsl);       /* SDTM DM DS EX SV VS SC MH QS -> ADSL_V1 */
%RUN_PGM(adam/adae);       /* ADSL_V1 + AE                 -> ADAE_V1 */
%RUN_PGM(adam/adlbc);      /* ADSL_V1 + LB                 -> ADLBC_V1 */
%RUN_PGM(adam/adlbh);      /* ADSL_V1 + LB                 -> ADLBH_V1 */
%RUN_PGM(adam/adlbhy);     /* ADSL_V1 + ADLBC_V1           -> ADLBHY_V1 */
%RUN_PGM(adam/advs);       /* ADSL_V1 + VS                 -> ADVS_V1 */
%RUN_PGM(adam/adqsadas);   /* ADSL_V1 + QS                 -> ADQSADAS_V1 */
%RUN_PGM(adam/adqscibc);   /* ADSL_V1 + QS                 -> ADQSCIBC_V1 */
%RUN_PGM(adam/adqsnpix);   /* ADSL_V1 + QS                 -> ADQSNPIX_V1 */
%RUN_PGM(adam/adtte);      /* ADSL_V1 + ADAE_V1            -> ADTTE_V1 */

/*--- Tables ---*/
%RUN_PGM(tfl/t14_1_01_02); /* Tables 14-1.01 and 14-1.02 */
%RUN_PGM(tfl/t14_2_01);    /* Table 14-2.01 */
%RUN_PGM(tfl/t14_3_01);    /* Table 14-3.01 */
