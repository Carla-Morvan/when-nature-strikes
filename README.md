# When Nature Strikes Repeatedly: Are Municipalities Fiscally Resilient?

**Carla Morvan**, 2026

## Overview

This repository contains the replication code for the paper *"When Nature Strikes Repeatedly: Are Municipalities Fiscally Resilient?"* This paper analyzes the causal impact of flood exposure on municipal budgets in France over the period 2000--2024, using the non-binary staggered difference-in-differences estimator of de Chaisemartin & D'Haultfoeuille (2024). The results document a pattern of apparent fiscal resilience that conceals important heterogeneity across disaster frequency, financial health, and household income.

## Repository Structure

    .
    ├── README.md
    ├── data/
    │   ├── README_data.md
    │   ├── data_budgetco.parquet
    │   └── catnat_gaspar.csv
    ├── code/
    │   ├── 00_prepare_data.R
    │   ├── 01_build_sample.R
    │   ├── 02_estimation.R
    │   ├── 03_figures.R
    │   └── 04_tables.R
    ├── results/
    │   ├── main/
    │   ├── heterogeneity/
    │   │   ├── nb_floods/
    │   │   ├── afl/
    │   │   └── income/
    │   └── robustness/
    ├── figures/
    └── tables/

## Data

Two processed datasets are provided in the `data/` folder. `data_budgetco.parquet` contains municipal budget accounts for all French mainland municipalities over 2000--2024, merged with socioeconomic and geographic controls. `catnat_gaspar.csv` contains natural disaster records from the GASPAR database (French Ministry of Environment), covering 1982--2024. See `data/README_data.md` for a complete description of sources and variables.

**Note on geographic data**: The map figure requires shapefiles for French municipalities and national boundaries, available from [IGN AdminExpress](https://geoservices.ign.fr/adminexpress). These files are not included in the repository due to size constraints.

## Replication

**Requirements**: Install the following R packages before running the scripts.

    install.packages(c(
      "arrow", "dplyr", "tidyr", "readr", "stringr",
      "lubridate", "ggplot2", "patchwork", "sf",
      "DIDmultiplegtDYN", "knitr", "scales"
    ))

**Steps**: Run the scripts in order. `01_build_sample.R` builds the estimation sample from the provided data. `02_estimation.R` runs all estimations. `03_figures.R` generates all figures. `04_tables.R` generates all tables.

**Warning**: `02_estimation.R` is computationally intensive. Each estimation takes approximately 30--60 minutes. The full set of estimations may take several days to complete.

**Output paths**: By default, results are saved to `results/`, figures to `figures/`, and tables to `tables/`. Adapt the `results_path` variable at the top of each script to match your local setup.

## Estimation Method

All estimations use the non-binary staggered difference-in-differences estimator implemented in the `DIDmultiplegtDYN` R package. The treatment variable is the cumulative number of flood and storm events since 2000 (`FLOODS_cumule2000`). Outcome variables include investment expenditures, current expenditures, grants, debt stock, and property and business tax rates and bases, all transformed using the inverse hyperbolic sine. Estimations use `normalized = TRUE`, `trends_nonparam = "risk_group"`, `cluster = "cod_commune"`, `effects = 10`, and `placebo = 3`. See Section 3 of the paper for details on the identification strategy.

Reference:  - de Chaisemartin, C. & D'Haultfoeuille, X. (2024). *Difference-in-Differences Estimators of Intertemporal Treatment Effects*.The Review of Economics and Statistics. 
- de Chaisemartin, C. & D'Haultfoeuille, X. (2026). *Causal Inference with Differences-in-447
Differences: Credible Answers to Hard Questions*. Princeton University Press. 

## Sample Construction

The main estimation sample is restricted to municipalities whose last recorded disaster before 2000 was the 1999 storms Lothar and Martin, ensuring a common pre-treatment baseline across municipalities. See Section 2.3 of the paper for details.

## Contact

Carla Morvan
