# Developer Guide: Parquet Migration for Founder Diet Study

This guide provides technical specifications, schemas, data scale metrics, and migration recipes for database and data lakehouse engineers converting the **Founder Diet Study** dataset to Apache Parquet.

---

## 1. Executive Summary & Objectives

The Founder Diet Study is a multi-omics research initiative characterizing metabolic responses across the 8 founder strains of the Collaborative Cross / Diversity Outbred mouse population (`129`, `AJ`, `B6`, `CAST`, `NOD`, `NZO`, `PWK`, `WSB`) under two diet conditions (`HC_LF` = High Carbohydrate, Low Fat; `HF_LC` = High Fat, Low Carbohydrate) across both sexes (`M`, `F`) across 192 animals.

Currently, harmonized data are stored as R serialization files (`.rds`), CSV files, and a monolithic SQLite database (`traitData.sqlite`, ~192 MB) on network storage (`/mnt/researchdrive/adattie/` or `/Volumes/adattie/`). 

### Why Convert to Parquet?
1. **Network Storage Latency**: Random access and scans across SMB/NFS mounts for SQLite or multi-megabyte RDS files are high-latency.
2. **Columnar Projection & Predicate Pushdown**: Analysis and Shiny visualization tools frequently query single traits, specific datasets, or summary statistics without needing full table scans.
3. **Scale**: The largest layers contain tens of millions of rows (e.g., `LivIso` at ~19.8 million rows, `LivRna` at ~3.17 million rows). Parquet with ZSTD or Snappy compression reduces disk footprint by 75–85% while enabling vector execution via DuckDB, Arrow, and Polars.

---

## 2. Source Data Inventory & Scale

Data are organized within `HarmonizedData/` into standardized data layers:

| Layer / Folder | Modality | Primary Traits | Measured Entities | Estimated Row Count | Primary RDS Files |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`Physio/`** | In vivo physiology | Body weight, GTT/ITT glucose, insulin, ketones | ~140 physiological traits | ~34,166 | `PhysioData.rds`, `PhysioSignal.rds`, `PhysioStats.rds` |
| **`LivRna/`** | Liver transcriptomics | VST-normalized gene expression | ~16,500 genes | ~3,170,870 | `LivRnaData.rds`, `LivRnaSignal.rds`, `LivRnaStats.rds` |
| **`LivIso/`** | Liver RNA isoforms | VST-normalized transcript isoforms | ~103,000 isoforms | ~19,842,432 | `LivIsoData.rds`, `LivIsoSignal.rds`, `LivIsoStats.rds` |
| **`LivMet/`** | Liver metabolomics | Unique isobar-resolved metabolites | ~500 metabolites | ~96,000 | `LivMetData.rds`, `LivMetSignal.rds`, `LivMetStats.rds` |
| **`Lipid/`** | Liver lipidomics | Lipid species classes and tags | ~400 lipids | ~76,800 | `LipidData.rds`, `LipidSignal.rds`, `LipidStats.rds` |
| **`PlaMet*`** | Plasma metabolomics | Baseline (0 min), 120 min, all timepoints | ~300 metabolites | ~57,600 | `PlaMet0Data.rds`, `PlaMet120Data.rds` |
| **`Enrich*`** | Stable isotope tracer | 13C and Deuterium fractional enrichment | ~100 timepoints/analytes | ~19,200 | `EnrichData.rds`, `LivEnrichData.rds` |
| **`Module/`** | Network modules | WGCNA eigengenes & module kME values | Cross-trait clusters | Variable | `ModuleData.rds`, `ModuleStats.rds` |

**Total Core Observation Table Size**: ~23.3 million rows across all modalities.

---

## 3. Recommended Relational Target Schema

A database expert should decouple the data into clean, typed, dimensional Parquet tables:

```
┌─────────────────────────────────┐
│         sample_metadata         │
├─────────────────────────────────┤
│ animal_id (PK)                  │
│ strain                          │
│ sex                             │
│ condition                       │
└────────────────┬────────────────┘
                 │ 1:N
┌────────────────▼────────────────┐          ┌─────────────────────────────────┐
│           trait_data            │   N:1    │          feature_info           │
├─────────────────────────────────┤◄─────────┤─────────────────────────────────┤
│ dataset                         │          │ feature_id / trait (PK)         │
│ animal_id                       │          │ ensembl_id                      │
│ trait                           │          │ name / symbol                   │
│ value                           │          │ biotype                         │
└─────────────────────────────────┘          │ chromosome, start, end          │
                                             └─────────────────────────────────┘
┌─────────────────────────────────┐
│          trait_signals          │
├─────────────────────────────────┤
│ dataset, strain, sex            │
│ condition, trait                │
│ signal, cellmean                │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│           trait_stats           │
├─────────────────────────────────┤
│ dataset, trait, term            │
│ SD, p_value                     │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│          wgcna_modules          │
├─────────────────────────────────┤
│ dataset, subset, trait          │
│ module, kME                     │
└─────────────────────────────────┘
```

### Table Definitions & Arrow Data Types

#### 1. `trait_data` (Fact Table: Individual Animal Observations)
*Source: `HarmonizedData/<Layer>/<Layer>Data.rds` or `HarmonizedData/Normalized/traitData.csv`*

| Column | Arrow / Parquet Type | Recommended Encoding | Description |
| :--- | :--- | :--- | :--- |
| `dataset` | `string` / `dictionary` | Dictionary | Modality (`Physio`, `LivRna`, `LivMet`, `Lipid`, `LivIso`) |
| `strain` | `string` / `dictionary` | Dictionary | 8 founders: `129`, `AJ`, `B6`, `CAST`, `NOD`, `NZO`, `PWK`, `WSB` |
| `sex` | `string` / `dictionary` | Dictionary | `M` or `F` |
| `animal` | `int16` | Plain / Bit-packed | Animal identification number (1 to 192) |
| `condition` | `string` / `dictionary` | Dictionary | Diet: `HC_LF` (High Carb Low Fat) or `HF_LC` (High Fat Low Carb) |
| `trait` | `string` | Plain / Delta | Measured trait name, gene symbol, or metabolite ID |
| `value` | `float32` (or `float64`) | Plain | Observed measurement (raw, VST, or normalized) |

#### 2. `trait_signals` (Modeled Cell Means and Effects)
*Source: `HarmonizedData/<Layer>/<Layer>Signal.rds` or `HarmonizedData/Normalized/traitSignal.csv`*

| Column | Arrow / Parquet Type | Recommended Encoding | Description |
| :--- | :--- | :--- | :--- |
| `dataset` | `string` / `dictionary` | Dictionary | Modality (`Physio`, `LivRna`, etc.) |
| `strain` | `string` / `dictionary` | Dictionary | Founder strain |
| `sex` | `string` / `dictionary` | Dictionary | Sex (`M`, `F`) |
| `condition` | `string` / `dictionary` | Dictionary | Diet (`HC_LF`, `HF_LC`) |
| `trait` | `string` | Plain | Trait or feature name |
| `signal` | `float64` | Plain | Model-estimated signal effect |
| `cellmean` | `float64` | Plain | Strain-sex-diet specific fitted mean |

#### 3. `trait_stats` (ANOVA / Model Terms and Significance)
*Source: `HarmonizedData/<Layer>/<Layer>Stats.rds` or `HarmonizedData/Normalized/traitStats.csv`*

| Column | Arrow / Parquet Type | Recommended Encoding | Description |
| :--- | :--- | :--- | :--- |
| `dataset` | `string` / `dictionary` | Dictionary | Modality |
| `trait` | `string` | Plain | Feature / trait identifier |
| `term` | `string` / `dictionary` | Dictionary | Model component (`signal`, `cellmean`, `strain`, `sex`, `rest`, `noise`) |
| `sd` | `float64` | Plain | Standard deviation / variance component |
| `p_value` | `float64` | Plain | Empirical or model p-value (`NA` for noise) |

#### 4. `feature_annotations` (Gene and Isoform Metadata)
*Source: `HarmonizedData/gene_info.csv`*

| Column | Arrow / Parquet Type | Description |
| :--- | :--- | :--- |
| `ensembl_gene_id` | `string` | Ensembl gene identifier (e.g., `ENSMUSG00000000001`) |
| `external_gene_name` | `string` | Standard gene symbol (e.g., `Gnai3`, `Cdc45`) |
| `gene_biotype` | `string` / `dictionary` | Biotype (`protein_coding`, `lncRNA`, etc.) |
| `chromosome_name` | `string` / `dictionary` | Chromosome (`1`–`19`, `X`, `Y`, `MT`) |
| `start_position` | `int64` | Genomic start coordinate |
| `end_position` | `int64` | Genomic end coordinate |
| `description` | `string` | Functional gene description |

#### 5. `wgcna_modules` (Network Module Memberships)
*Source: `HarmonizedData/<Layer>/<Layer>Module.rds`*

| Column | Arrow / Parquet Type | Description |
| :--- | :--- | :--- |
| `dataset` | `string` / `dictionary` | Source dataset (`LivRna`, `Physio`, `LivMet`) |
| `subset` | `string` / `dictionary` | Stratification (`Both Sexes`, `Female`, `Male`, `Sex Contrast`) |
| `trait` | `string` | Trait or gene identifier |
| `module` | `string` / `dictionary` | Assigned color module (e.g., `turquoise`, `blue`, `grey`) |
| `kme` | `float64` | Module membership score / eigengene correlation |

---

## 4. Partitioning & Storage Architecture

### Recommended Directory Layout

```
parquet_db/
├── trait_data/
│   ├── dataset=Physio/part-0.parquet
│   ├── dataset=LivMet/part-0.parquet
│   ├── dataset=Lipid/part-0.parquet
│   ├── dataset=LivRna/
│   │   ├── condition=HC_LF/part-0.parquet
│   │   └── condition=HF_LC/part-0.parquet
│   └── dataset=LivIso/
│       ├── condition=HC_LF/part-0.parquet
│       └── condition=HF_LC/part-0.parquet
├── trait_signals/
│   └── dataset=*/part-0.parquet
├── trait_stats/
│   └── dataset=*/part-0.parquet
├── feature_annotations/
│   └── gene_info.parquet
└── wgcna_modules/
    └── dataset=*/part-0.parquet
```

### Partitioning Rules of Thumb
- **Partition by `dataset`**: Most analytical queries and application views target a single modality (e.g., only physiological traits, or only liver RNA). Partitioning by `dataset` allows query engines to skip 90%+ of files instantly.
- **Sub-partition large modalities**: For `LivIso` (~19.8M rows) and `LivRna` (~3.17M rows), sub-partitioning by `condition` (`HC_LF` vs `HF_LC`) or `sex` ensures individual Parquet files remain between 50 MB and 250 MB.
- **DO NOT partition by `trait` or `animal`**: Partitioning by high-cardinality keys creates thousands of small files, which destroys I/O throughput on network-attached storage (SMB/ResearchDrive).
- **Row Group Size**: Set row group size between `250,000` and `500,000` rows to balance memory usage during decompression and pruning efficiency.
- **Compression**: Use `zstd` (compression level 3 or 5) for ideal compression ratio and read speeds.

---

## 5. Conversion Recipes

### A. R Conversion Pipeline (using `arrow`)

The `arrow` R package is already available in the environment. Here is a production-grade script to extract `.rds` files and write partitioned Parquet datasets:

```r
library(arrow)
library(dplyr)
library(purrr)

base_dir <- "/Volumes/adattie/General/founder_diet_study/HarmonizedData"
output_dir <- file.path(base_dir, "parquet")

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# 1. Convert Data layers
layers <- c("Physio", "LivRna", "LivIso", "LivMet", "Lipid", "Vivo")

for (layer in layers) {
  rds_path <- file.path(base_dir, layer, paste0(layer, "Data.rds"))
  if (file.exists(rds_path)) {
    message("Converting ", layer, "Data.rds...")
    df <- readRDS(rds_path) %>%
      mutate(
        dataset = as.character(layer),
        animal = as.integer(animal),
        strain = as.factor(strain),
        sex = as.factor(sex),
        condition = as.factor(condition),
        value = as.numeric(value)
      )
    
    write_dataset(
      df,
      file.path(output_dir, "trait_data"),
      format = "parquet",
      partitioning = c("dataset"),
      compression = "zstd",
      compression_level = 5
    )
  }
}

# 2. Convert Signal layers
for (layer in layers) {
  rds_path <- file.path(base_dir, layer, paste0(layer, "Signal.rds"))
  if (file.exists(rds_path)) {
    message("Converting ", layer, "Signal.rds...")
    df <- readRDS(rds_path) %>%
      mutate(dataset = as.character(layer))
    
    write_dataset(
      df,
      file.path(output_dir, "trait_signals"),
      format = "parquet",
      partitioning = c("dataset"),
      compression = "zstd"
    )
  }
}

# 3. Convert Stats layers
for (layer in layers) {
  rds_path <- file.path(base_dir, layer, paste0(layer, "Stats.rds"))
  if (file.exists(rds_path)) {
    message("Converting ", layer, "Stats.rds...")
    df <- readRDS(rds_path) %>%
      mutate(dataset = as.character(layer))
    
    write_dataset(
      df,
      file.path(output_dir, "trait_stats"),
      format = "parquet",
      partitioning = c("dataset"),
      compression = "zstd"
    )
  }
}

# 4. Convert Feature Annotations
gene_info_path <- file.path(base_dir, "gene_info.csv")
if (file.exists(gene_info_path)) {
  message("Converting gene_info.csv...")
  gene_df <- read.csv(gene_info_path) %>%
    select(-any_of("X"))
  
  write_parquet(
    gene_df,
    file.path(output_dir, "feature_annotations", "gene_info.parquet"),
    compression = "zstd"
  )
}
```

### B. Python / PyArrow Conversion Recipe

```python
import pyarrow as pa
import pyarrow.csv as csv
import pyarrow.parquet as pq
import pyarrow.dataset as ds
from pathlib import Path

base_path = Path("/Volumes/adattie/General/founder_diet_study/HarmonizedData")
out_path = base_path / "parquet"

# Example: Converting traitData.csv to partitioned Parquet
csv_file = base_path / "Normalized" / "traitData.csv"
if csv_file.exists():
    table = csv.read_csv(csv_file)
    pq.write_to_dataset(
        table,
        root_path=str(out_path / "trait_data_normalized"),
        partition_cols=["dataset"],
        compression="zstd",
        compression_level=5,
        use_dictionary=["strain", "sex", "condition"],
    )
```

### C. SQL / DuckDB Direct Analysis Recipe

Once converted, engineers and analysts can execute zero-copy analytics on the Parquet files without spinning up an R session or loading tables into memory:

```sql
-- Query across all physiological traits for female mice on high-fat diet
SELECT 
    strain,
    trait,
    AVG(value) AS mean_val,
    STDDEV(value) AS sd_val,
    COUNT(*) AS n_mice
FROM read_parquet('/Volumes/adattie/General/founder_diet_study/HarmonizedData/parquet/trait_data/*/*.parquet')
WHERE dataset = 'Physio' 
  AND sex = 'F' 
  AND condition = 'HF_LC'
GROUP BY strain, trait
ORDER BY trait, strain;

-- Join gene expression with gene chromosome annotations
SELECT 
    d.animal,
    d.strain,
    d.trait AS gene_symbol,
    a.chromosome_name,
    a.start_position,
    d.value AS vst_expression
FROM read_parquet('/Volumes/adattie/General/founder_diet_study/HarmonizedData/parquet/trait_data/dataset=LivRna/*.parquet') d
JOIN read_parquet('/Volumes/adattie/General/founder_diet_study/HarmonizedData/parquet/feature_annotations/gene_info.parquet') a
  ON d.trait = a.external_gene_name
WHERE a.chromosome_name = '7'
LIMIT 50;
```

---

## 6. Performance & Network Drive Gotchas

1. **Local Staging**: Network shares (such as SMB mounts on `/Volumes/adattie/`) suffer from high per-operation metadata latency. Always stage raw Parquet outputs locally (e.g., `/tmp/parquet_stage/`), build row groups, and copy the completed folder hierarchy to the final network drive in one batch.
2. **Schema Uniformity**: Ensure that `animal` is consistently cast as an integer across all layers, and `value` as `float64` (or `float32`). If different partitions have mismatched types (e.g. `animal` as string in one layer and integer in another), schema reconciliation in DuckDB and Spark will fail.
3. **Empty / Obsolete Directories**: Ignore `HarmonizedData/Obsolete/`, `HarmonizedData/Old/`, and `RawData/Obsolete/` during migration. They contain unaligned intermediate outputs from 2023.
