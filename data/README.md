# Input data

No data is stored in this repository. All inputs are public and come from the CDISC SDTM/ADaM Pilot Project (study CDISCPILOT01):

- Repository: https://github.com/cdisc-org/sdtm-adam-pilot-project (updated pilot submission package)
- SDTM transport files used: `dm.xpt`, `ds.xpt`, `ex.xpt`, `sv.xpt`, `vs.xpt`, `sc.xpt`, `mh.xpt`, `qs.xpt`, `ae.xpt`, `lb.xpt`
- Reference ADaM transport files used for QC: `adsl.xpt`, `adae.xpt`, `adlbc.xpt`, `adlbh.xpt`, `adlbhy.xpt`, `advs.xpt`, `adqsadas.xpt`, `adqscibc.xpt`, `adqsnpix.xpt`, `adtte.xpt`
- Specifications: the study define.xml and the CSR, which contains the SAP and the table shells

Place the `.xpt` files in one folder and set `ROOT` in `setup.sas` to that folder.
