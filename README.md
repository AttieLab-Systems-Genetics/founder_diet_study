# Support repository for Founder Diet Study

See <https://connect.doit.wisc.edu/FounderDietStudy/> app (limited access) for interactive data tool. More information found in
[byandell-sysgen/FounderDietStudy](https://github.com/byandell-sysgen/FounderDietStudy).

## Interactive App

- <https://connect.doit.wisc.edu/FounderDietStudy/>: interactive app on RStudio Connect
- [app.R](https://github.com/byandell-sysgen/FounderDietStudy/blob/main/deployNew/app.R): code for app
- [foundrDietStudy.R](https://github.com/byandell-sysgen/FounderDietStudy/blob/main/foundrDietStudy.R): support code for app
- <https://github.com/byandell-sysgen/foundr>: support package for app

## Support Rmarkdown Document

These may need some updating in future.

- [FounderDietStudy_Data.Rmd](https://github.com/byandell-sysgen/FounderDietStudy/blob/main/FounderDietStudy_Data.Rmd): Harmonize raw data for further analysis.
- [FounderDietStudy.Rmd](https://github.com/byandell-sysgen/FounderDietStudy/blob/main/FounderDietStudy.Rmd): initial study of founder diet study
- [FounderDietStudy_cor.Rmd](https://github.com/byandell-sysgen/FounderDietStudy/blob/main/FounderDietStudy_cor.Rmd): correlation study across founders
- [FounderDietExplore.Rmd](https://github.com/byandell-sysgen/FounderDietStudy/blob/main/FounderDietExplore.Rmd)

## Archived Data

Data are archived in [ResearchDrive](https://kb.wisc.edu/researchdata/internal/page.php?id=93998#connect) with access via Attie Lab. They include the following:

- RawData
  - Data collated by Mark Keller. Much copied from [Founder diet data Google Drive](https://drive.google.com/drive/u/1/folders/1v2xyz0s0ELYkEwMdEOMjAvLVWJA1OkGG).
- HarmonizedData
  - Beginnings of harmonized data developed by Brian Yandell. See [DEVELOPER.md](DEVELOPER.md) for data lakehouse schemas and Parquet conversion documentation.

## RawData Folder

- **`Annotation/`**
  - Mouse metadata and sample annotation tables (`mouse annotations for founder diet study.xlsx`).
- **`Enrich/`**
  - Dynamic plasma tracer enrichment timecourse data (13C and Deuterium labels).
- **`LivMet/`**
  - Liver metabolomics profiles (raw and normalized) with resolved isobaric peaks.
- **`LivRna/`**
  - Liver transcriptomics count matrices, variance-stabilizing transformations (VST/VSD), and sequencing QC reports.
- **`Physio/`**
  - In vivo physiological traits, body weight, ketone levels, and correlation datasets.
- **`PlaMet/`**
  - Plasma metabolomics at baseline (T0) and 120-minute post-challenge timepoints.
- **`WGCNA_modules/`**
  - Co-expression network modules and eigengenes for liver RNA and metabolomics.
- **`source.csv`**
  - Source tracking table mapping data types to collaborator files and Google Drive paths.

## HarmonizedData Folder

- **`Physio/` & `Vivo/`**
  - Standardized in vivo physiological traits, body composition, and metabolic parameters formatted as `Data`, `Signal`, and `Stats` RDS objects.
- **`LivRna/` & `LivIso/`**
  - Harmonized liver gene and isoform expression matrices alongside WGCNA module assignments (`*Module.rds`).
- **`LivMet/` & `Lipid/`**
  - Harmonized liver metabolomics (resolved isobars) and liver lipidomic profiles.
- **`PlaMet/`, `PlaMet0/`, `PlaMet120/`, & `PlaMetAll/`**
  - Standardized plasma metabolomics at baseline (0 min), post-challenge (120 min), and across all timepoints.
- **`Enrich/`, `LivEnrich/`, & `PlaEnrich/`**
  - Harmonized stable isotope (13C, Deuterium) tracer enrichment time series in liver and plasma.
- **`Module/`, `MixMod/`, & `Metab/`**
  - Network module eigengenes, multi-omics mixed modules, and cross-dataset correlation metrics.
- **`Normalized/` & `Unnormalized/`**
  - Normal-scores transformed matrices (RDS, CSV, SQLite) used by the Shiny application and raw comparison sets.
- **`AppSetup/` & `deploy/`**
  - Deployment scripts, configuration (`appSetup.R`), and documentation for the interactive RStudio Connect app.
  - Refer to more recent [deployNew](https://github.com/byandell-sysgen/FounderDietStudy/tree/main/deployNew) for current deployment.
- **`R/`**
  - Modular R scripts used to harmonize and transform raw datasets into standardized structures.
  - See [foundrHarmony](https://github.com/byandell-sysgen/foundrHarmony) for current schema.
- **Root RDS Files (`traitObject.rds`, `liverObject.rds`, `PhysMixObject.rds`)**
  - High-level composite multi-omics objects combining data, statistics, and signals for interactive visualization.

Brian S. Yandell <brian.yandell@wisc.edu> 30 January 2023; revised 2 October 2026.
