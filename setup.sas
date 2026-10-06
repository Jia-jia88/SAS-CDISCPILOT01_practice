/*==========================================================================
  Program   : setup.sas
  Purpose   : Central location for all folder paths and the ADAM library.
              Every program in programs/ resolves its paths from the macro
              variables defined here, so nothing else needs editing when the
              project is moved to another environment.
  Usage     : Edit ROOT below, then run this file once per SAS session
              (run_all.sas does this automatically).
==========================================================================*/

/* Folder that holds the input .xpt files and the derived ADaM datasets.
   In SAS OnDemand for Academics this is typically /home/<user-id>/sasuser.v94 */
%LET ROOT = /home/<your-user-id>/sasuser.v94;

%LET SDTMPATH = &ROOT;   /* CDISCPILOT01 SDTM transport files (dm.xpt, ae.xpt, ...)         */
%LET REFPATH  = &ROOT;   /* CDISCPILOT01 reference ADaM transport files, used for QC only   */
%LET ADAMPATH = &ROOT;   /* Library where the derived ADaM datasets (*_V1) are written      */
%LET OUTPATH  = &ROOT;   /* Destination for RTF table outputs                               */

LIBNAME ADAM "&ADAMPATH";
