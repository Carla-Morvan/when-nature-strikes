# When Nature Strikes Repeatedly: Are Municipalities Fiscally Resilient?

**Carla Morvan**, 2026

## Overview

This repository contains the replication code for the paper *"When Nature Strikes Repeatedly: Are Municipalities Fiscally Resilient?"* This paper analyzes the causal impact of flood exposure on municipal budgets in France over the period 2000--2024, using the non-binary staggered difference-in-differences estimator of de Chaisemartin & D'Haultfoeuille (2024). The results document a pattern of apparent fiscal resilience that conceals important heterogeneity across disaster frequency, financial health, and household income.

## Repository Structure

    .
    ├── README.md
    ├── data/
    │   └── README.md              # Data sources and variable dictionary
    └── code/
        ├── 00_prepare_data.R      # Build base dataset from raw data
        ├── 01_build_sample.R      # Build estimation sample
        ├── 02_estimation.R        # Run all estimations
        ├── 03_figures.R           # Generate all figures
        └── 04_tables.R            # Generate all tables

## Data

No processed data files are included in this repository due to size constraints. All raw data are publicly available from the sources listed in `data/README.md`, with the exception of the AFL financial health score (see Note on Replication below).

To replicate the analysis, download the raw data from the sources listed in `data/README.md` and run `00_prepare_data.R` to build the base dataset, then proceed with the subsequent scripts.

**Note on geographic data**: The map figure requires shapefiles for French municipalities and national boundaries, available from [OpenStreetMap](https://www.data.gouv.fr/datasets/decoupage-administratif-communal-francais-issu-d-openstreetmap).

## Replication

**Requirements**: Install the following R packages before running the scripts.

    install.packages(c(
      "arrow", "dplyr", "tidyr", "readr", "stringr",
      "lubridate", "ggplot2", "patchwork", "sf",
      "DIDmultiplegtDYN", "knitr", "scales", "purrr"
    ))

**Steps**: Run the scripts in order.

- `00_prepare_data.R` builds the base dataset from raw data sources.
- `01_build_sample.R` builds the estimation sample `df_run`.
- `02_estimation.R` runs all estimations.
- `03_figures.R` generates all figures.
- `04_tables.R` generates all tables.

**Warning**: `02_estimation.R` is computationally intensive. Each estimation takes approximately 30--60 minutes. The full set of estimations may take several days to complete.

**Output paths**: Results are saved to `results/`, figures to `figures/`, and tables to `tables/`. Adapt the `results_path` variable at the top of each script to match your local setup.

## Note on Replication

All results except the heterogeneity analysis by financial health are fully replicable from publicly available data and the provided code. The AFL financial health score used in the heterogeneity section is based on a proprietary banking formula developed by the AFL (Agence France Locale); the underlying data are not publicly available. Results from this analysis are available upon reasonable request.

## Estimation Method

All estimations use the non-binary staggered difference-in-differences estimator implemented in the `DIDmultiplegtDYN` R package. The treatment variable is the cumulative number of flood and storm events since 2000 (`FLOODS_cumule2000`). Outcome variables include investment expenditures, current expenditures, grants, debt stock, and property and business tax rates and bases, all transformed using the inverse hyperbolic sine. Estimations use `normalized = TRUE`, `trends_nonparam = "risk_group"`, `cluster = "cod_commune"`, `effects = 10`, and `placebo = 3`. See Section 3 of the paper for details on the identification strategy.

Reference: de Chaisemartin, C. & D'Haultfoeuille, X. (2024). *Difference-in-Differences Estimators of Intertemporal Treatment Effects*. The Review of Economics and Statistics.

## Sample Construction

The main estimation sample is restricted to municipalities whose last recorded disaster before 2000 was the 1999 storms Lothar and Martin, ensuring a common pre-treatment baseline across municipalities. See Section 2.3 of the paper for details.

## Contact

Carla Morvan
